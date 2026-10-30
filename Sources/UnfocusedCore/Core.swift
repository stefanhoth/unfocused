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

  /// Captures a new Open Loop with the given title.
  @discardableResult
  public func capture(title: String) throws -> Loop {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw CoreError.emptyTitle }
    let loop = Loop(id: UUID(), title: trimmed, state: .open, capturedAt: time.now)
    try database.writer.write { db in
      try LoopRecord(loop).insert(db)
      var event = LoopEventRecord(loopID: loop.id, change: .captured, at: loop.capturedAt)
      try event.insert(db)
    }
    return loop
  }

  /// Makes `loopID` the Focused Loop, ending any other Focus.
  /// Focusing the already Focused Loop changes nothing.
  public func focus(_ loopID: UUID) throws {
    let now = time.now.timeIntervalSince1970
    try database.writer.write { db in
      guard let record = try LoopRecord.fetchOne(db, key: loopID.uuidString) else { throw CoreError.loopNotFound }
      guard record.state == LoopState.open.rawValue else { throw CoreError.loopNotOpen }
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

  private static func openFocus(_ db: Database) throws -> FocusSessionRecord? {
    try FocusSessionRecord.filter(Column("end") == nil).order(Column("start").desc).fetchOne(db)
  }

  private static func end(_ session: FocusSessionRecord, at time: Double, _ db: Database) throws {
    var ended = session
    ended.end = time
    try ended.update(db)
  }
}
