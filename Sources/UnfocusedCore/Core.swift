import Foundation
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

  // MARK: Queries

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
}
