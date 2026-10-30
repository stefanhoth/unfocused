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
    try database.writer.write { db in try LoopRecord(loop).insert(db) }
    return loop
  }

  /// Makes `loopID` the Focused Loop, ending any other Focus.
  /// Focusing the already Focused Loop changes nothing.
  public func focus(_ loopID: UUID) throws {
    let now = time.now.timeIntervalSince1970
    try database.writer.write { db in
      guard try LoopRecord.fetchOne(db, key: loopID.uuidString) != nil else { throw CoreError.loopNotFound }
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

  private static func openFocus(_ db: Database) throws -> FocusSessionRecord? {
    try FocusSessionRecord.filter(Column("end") == nil).order(Column("start").desc).fetchOne(db)
  }

  private static func end(_ session: FocusSessionRecord, at time: Double, _ db: Database) throws {
    var ended = session
    ended.end = time
    try ended.update(db)
  }
}
