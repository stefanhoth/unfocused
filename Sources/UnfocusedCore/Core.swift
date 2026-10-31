public import Foundation
import GRDB

/// The public interface of unfocused's domain: commands in, answers out (ADR 0005).
public final class Core: Sendable {
  public let database: UnfocusedDatabase
  let time: any TimeSource

  public init(database: UnfocusedDatabase, time: any TimeSource = SystemTime()) {
    self.database = database
    self.time = time
  }

  // MARK: Commands

  /// Captures a new Open Loop. With an Anchor, an empty title falls back to the Anchor's title.
  /// `@name` mentions in the title involve those People (created if new), as Owed unless
  /// `directions` says otherwise; the `@` is dropped from the title.
  @discardableResult
  public func capture(title: String, anchor: Anchor? = nil, directions: [String: Direction] = [:]) throws -> Loop {
    let now = time.now
    return try database.writer.write { db in
      let known = try PersonRecord.fetchAll(db).map(\.name)
      let parsed = Mentions.parse(title, knownNames: known)
      var trimmed = parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty, let anchor { trimmed = anchor.title }
      guard !trimmed.isEmpty else { throw CoreError.emptyTitle }
      let loop = Loop(id: UUID(), title: trimmed, state: .open, capturedAt: now)
      try LoopRecord(loop).insert(db)
      for name in parsed.names {
        let person = try Self.person(named: name, evenIfSimilar: true, db)
        let direction = directions.first { NameMatching.key($0.key) == NameMatching.key(name) }?.value ?? .owed
        try InvolvementRecord(loopId: loop.id.uuidString, personId: person.id.uuidString, direction: direction.rawValue)
          .insert(db, onConflict: .replace)
      }
      var event = LoopEventRecord(loopID: loop.id, change: .captured, at: loop.capturedAt)
      try event.insert(db)
      if let anchor {
        var record = AnchorRecord(loopID: loop.id, anchor: anchor, addedAt: loop.capturedAt)
        try record.insert(db)
      }
      return loop
    }
  }

  /// Makes `loopID` the Focused Loop, ending any other Focus.
  /// Focusing the already Focused Loop changes nothing.
  public func focus(_ loopID: UUID) throws {
    let now = time.now.timeIntervalSince1970
    try database.writer.write { db in
      guard let record = try LoopRecord.fetchOne(db, key: loopID.uuidString) else { throw CoreError.loopNotFound }
      guard record.state == LoopState.open.rawValue else { throw CoreError.loopNotOpen }
      try Self.clearInterruption(db)
      if let current = try Self.openFocus(db) {
        if current.loopId == loopID.uuidString { return }
        try Self.end(current, at: now, db)
      }
      var session = FocusSessionRecord(id: nil, loopId: loopID.uuidString, start: now, end: nil)
      try session.insert(db)
    }
  }

  /// Ends the current Focus, if any. Afterwards the user is unfocused.
  public func unfocus() throws {
    let now = time.now.timeIntervalSince1970
    try database.writer.write { db in
      try Self.clearInterruption(db)
      if let current = try Self.openFocus(db) { try Self.end(current, at: now, db) }
    }
  }

  /// Marks an Open Loop as finished. Ends its Focus if it was Focused.
  public func close(_ loopID: UUID) throws {
    try change(loopID, from: [.open], to: .closed, recording: .closed)
  }

  /// Consciously lets go of an Open Loop. Ends its Focus if it was Focused.
  public func drop(_ loopID: UUID) throws {
    try change(loopID, from: [.open], to: .dropped, recording: .dropped)
  }

  /// Brings a Closed or Dropped Loop back to Open.
  public func reopen(_ loopID: UUID) throws {
    try change(loopID, from: [.closed, .dropped], to: .open, recording: .reopened)
  }

  /// Records how to get back into a Loop. An empty note keeps the previous one.
  public func setWhereILeftOff(_ loopID: UUID, to note: String) throws {
    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
    try database.writer.write { db in
      guard var record = try LoopRecord.fetchOne(db, key: loopID.uuidString) else { throw CoreError.loopNotFound }
      guard !trimmed.isEmpty else { return }
      record.whereILeftOff = trimmed
      record.editedAt = time.now.timeIntervalSince1970
      try record.update(db)
    }
  }

  // MARK: Queries

  /// The Loop with this id, in any state.
  public func loop(_ loopID: UUID) throws -> Loop? {
    try database.writer.read { db in try LoopRecord.fetchOne(db, key: loopID.uuidString)?.loop }
  }

  /// The Focused Loop, or `nil` when the user is unfocused.
  public func focusedLoop() throws -> Loop? {
    try database.writer.read { db in
      guard let current = try Self.openFocus(db) else { return nil }
      return try LoopRecord.fetchOne(db, key: current.loopId)?.loop
    }
  }

  /// Loops in `state`, most recently changed first.
  public func loops(in state: LoopState) throws -> [Loop] {
    try database.writer.read { db in
      try LoopRecord
        .filter(Column("state") == state.rawValue)
        .order(Column("stateChangedAt").desc, Column("capturedAt").desc)
        .fetchAll(db)
        .map(\.loop)
    }
  }

  /// The Loop that already has an Anchor at the same spot: an Open one if there is one, otherwise
  /// the most recently changed Closed or Dropped one (so it can be reopened).
  public func loop(anchoredAt anchor: Anchor) throws -> Loop? {
    try database.writer.read { db in
      let loopIDs = try String.fetchAll(
        db,
        sql: "SELECT DISTINCT loopId FROM anchor WHERE identifier = ?",
        arguments: [anchor.identifier]
      )
      let loops = try LoopRecord.filter(keys: loopIDs).fetchAll(db)
      let ranked = loops.sorted { lhs, rhs in
        let lhsOpen = lhs.state == LoopState.open.rawValue
        let rhsOpen = rhs.state == LoopState.open.rawValue
        return lhsOpen != rhsOpen ? lhsOpen : lhs.stateChangedAt > rhs.stateChangedAt
      }
      return ranked.first?.loop
    }
  }

  /// Adds an Anchor to a Loop. Adding the same spot twice changes nothing.
  public func addAnchor(_ anchor: Anchor, to loopID: UUID) throws {
    let now = time.now
    try database.writer.write { db in
      guard try LoopRecord.fetchOne(db, key: loopID.uuidString) != nil else { throw CoreError.loopNotFound }
      let exists =
        try AnchorRecord
        .filter(Column("loopId") == loopID.uuidString && Column("identifier") == anchor.identifier)
        .fetchCount(db) > 0
      guard !exists else { return }
      var record = AnchorRecord(loopID: loopID, anchor: anchor, addedAt: now)
      try record.insert(db)
      try Self.markEdited(loopID, at: now, db)
    }
  }

  public func removeAnchor(_ anchor: Anchor, from loopID: UUID) throws {
    let now = time.now
    try database.writer.write { db in
      _ =
        try AnchorRecord
        .filter(Column("loopId") == loopID.uuidString && Column("identifier") == anchor.identifier)
        .deleteAll(db)
      try Self.markEdited(loopID, at: now, db)
    }
  }

  /// A Loop's Anchors, in the order they were added.
  public func anchors(of loopID: UUID) throws -> [Anchor] {
    try database.writer.read { db in
      try AnchorRecord
        .filter(Column("loopId") == loopID.uuidString)
        .order(Column("addedAt"), Column("id"))
        .fetchAll(db)
        .map(\.anchor)
    }
  }

  /// What happened to a Loop, oldest first.
  public func history(for loopID: UUID) throws -> [LoopEvent] {
    try database.writer.read { db in
      try LoopEventRecord
        .filter(Column("loopId") == loopID.uuidString)
        .order(Column("at"), Column("id"))
        .fetchAll(db)
        .map(\.event)
    }
  }

  /// Every Focus of a Loop, oldest first.
  public func focusSessions(for loopID: UUID) throws -> [FocusSession] {
    try database.writer.read { db in
      try FocusSessionRecord
        .filter(Column("loopId") == loopID.uuidString)
        .order(Column("start"))
        .fetchAll(db)
        .map(\.session)
    }
  }

  /// All Open Loops, newest first.
  public func openLoops() throws -> [Loop] {
    try database.writer.read { db in
      try LoopRecord
        .filter(Column("state") == LoopState.open.rawValue)
        .order(Column("capturedAt").desc)
        .fetchAll(db)
        .map(\.loop)
    }
  }

  /// Open Loops matching `query` fuzzily, best match first; ties go to the newest.
  /// An empty query returns all Open Loops.
  public func searchOpenLoops(_ query: String) throws -> [Loop] {
    let loops = try openLoops()
    guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return loops }
    return
      loops
      .compactMap { loop in FuzzyMatch.score(query: query, in: loop.title).map { (loop, $0) } }
      .sorted { lhs, rhs in
        lhs.1 != rhs.1 ? lhs.1 > rhs.1 : lhs.0.capturedAt > rhs.0.capturedAt
      }
      .map(\.0)
  }

  // MARK: Helpers

  private func change(_ loopID: UUID, from allowed: Set<LoopState>, to target: LoopState, recording change: LoopChange)
    throws
  {
    let now = time.now
    try database.writer.write { db in
      guard var record = try LoopRecord.fetchOne(db, key: loopID.uuidString) else { throw CoreError.loopNotFound }
      guard let current = LoopState(rawValue: record.state), allowed.contains(current) else {
        throw CoreError.invalidStateChange
      }
      if target != .open { try Self.clearInterruption(of: record.id, db) }
      if target != .open, let focus = try Self.openFocus(db), focus.loopId == record.id {
        try Self.end(focus, at: now.timeIntervalSince1970, db)
      }
      record.state = target.rawValue
      record.stateChangedAt = now.timeIntervalSince1970
      try record.update(db)
      var event = LoopEventRecord(loopID: loopID, change: change, at: now)
      try event.insert(db)
    }
  }

  /// Records that the user changed a Loop's details, which counts as Engagement.
  static func markEdited(_ loopID: UUID, at time: Date, _ db: Database) throws {
    try db.execute(
      sql: "UPDATE loop SET editedAt = ? WHERE id = ?",
      arguments: [time.timeIntervalSince1970, loopID.uuidString]
    )
  }

  static func openFocus(_ db: Database) throws -> FocusSessionRecord? {
    try FocusSessionRecord.filter(Column("end") == nil).order(Column("start").desc).fetchOne(db)
  }

  static func end(_ session: FocusSessionRecord, at time: Double, _ db: Database) throws {
    var ended = session
    ended.end = time
    try ended.update(db)
  }
}
