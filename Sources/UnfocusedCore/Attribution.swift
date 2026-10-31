public import Foundation
import GRDB

/// Why a piece of Activity counts toward a Loop (or toward none).
public enum AttributionReason: String, Sendable, CaseIterable {
  /// It happened in one of the Loop's Anchors.
  case anchor
  /// It happened elsewhere while the Loop was Focused.
  case focus
  /// It matched no Loop.
  case unfocused
  /// It happened during a Focus, but the Reasoner judged it unrelated to the Focused Loop.
  case judgedUnrelated
}

/// A piece of Activity with the Loop it counts toward.
public struct AttributedStretch: Hashable, Sendable {
  public let anchor: Anchor
  public let start: Date
  public let end: Date
  /// `nil` for Unfocused time.
  public let loopID: UUID?
  public let reason: AttributionReason
  /// The Loop that was Focused at the time, if any.
  public let focusedLoopID: UUID?

  public init(
    anchor: Anchor,
    start: Date,
    end: Date,
    loopID: UUID?,
    reason: AttributionReason,
    focusedLoopID: UUID? = nil
  ) {
    self.anchor = anchor
    self.start = start
    self.end = end
    self.loopID = loopID
    self.reason = reason
    self.focusedLoopID = focusedLoopID
  }

  public var duration: TimeInterval { end.timeIntervalSince(start) }

  /// Unfocused time: it didn't go toward the Focused Loop, either because nothing was Focused or
  /// because it went elsewhere (another Loop's Anchor, or no Loop at all).
  public var isUnfocusedTime: Bool { focusedLoopID == nil || loopID != focusedLoopID }
}

extension Core {
  // MARK: Attribution

  /// Activity between `from` and `to`, each piece attributed by rule:
  /// time in a Loop's Anchor goes to that Loop, other time during a Focus goes to the Focused Loop,
  /// everything else goes to no Loop. Stretches are split where a Focus starts or ends.
  public func attributedActivity(from: Date, to: Date) throws -> [AttributedStretch] {
    let stretches = try activity(from: from, to: to)
    guard !stretches.isEmpty else { return [] }
    let now = time.now.timeIntervalSince1970
    let (owners, sessions, verdicts) = try database.writer.read { db in
      let anchors = try AnchorRecord.fetchAll(db)
      let loops = Dictionary(
        uniqueKeysWithValues: try LoopRecord.filter(keys: Set(anchors.map(\.loopId))).fetchAll(db).map { ($0.id, $0) }
      )
      let owners = Dictionary(
        grouping: anchors.compactMap { anchor in loops[anchor.loopId].map { (anchor.identifier, $0) } }
      ) {
        $0.0
      }
      .mapValues { $0.map(\.1) }
      let sessions =
        try FocusSessionRecord
        .filter(Column("start") <= to.timeIntervalSince1970)
        .filter(Column("end") == nil || Column("end") >= from.timeIntervalSince1970)
        .order(Column("start"))
        .fetchAll(db)
      return (owners, sessions, try Self.judgements(db))
    }

    return stretches.flatMap { stretch -> [AttributedStretch] in
      let candidates = owners[stretch.anchor.identifier] ?? []
      return Self.split(stretch, by: sessions, now: now).map { start, end, focusedID in
        let focused = UUID(uuidString: focusedID ?? "")
        if let owner = Self.preferredOwner(candidates, focused: focusedID) {
          return Self.piece(stretch, start, end, UUID(uuidString: owner.id), .anchor, focused)
        }
        if let focused, verdicts["\(stretch.anchor.identifier)|\(focused)"] == false {
          return Self.piece(stretch, start, end, nil, .judgedUnrelated, focused)
        }
        return Self.piece(stretch, start, end, focused, focused == nil ? .unfocused : .focus, focused)
      }
    }
  }

  /// Total Unfocused time between `from` and `to`: everything that didn't go toward the Focused Loop.
  public func unfocusedTime(from: Date, to: Date) throws -> TimeInterval {
    try attributedActivity(from: from, to: to).filter(\.isUnfocusedTime).reduce(0) { $0 + $1.duration }
  }

  /// When, where and why time was attributed to a Loop, oldest first.
  public func workLog(for loopID: UUID, from: Date, to: Date) throws -> [AttributedStretch] {
    try attributedActivity(from: from, to: to).filter { $0.loopID == loopID }
  }

  /// Time attributed to a Loop between `from` and `to`.
  public func timeSpent(on loopID: UUID, from: Date, to: Date) throws -> TimeInterval {
    try workLog(for: loopID, from: from, to: to).reduce(0) { $0 + $1.duration }
  }

  // MARK: Engagement

  /// The last time the user worked on a Loop: Focusing it (now, while Focused), being seen in one
  /// of its Anchors, or editing it. `nil` if none of that has happened since it was captured.
  public func lastEngagement(of loopID: UUID) throws -> Date? {
    let now = time.now.timeIntervalSince1970
    let latest = try database.writer.read { db -> Double? in
      guard let loop = try LoopRecord.fetchOne(db, key: loopID.uuidString) else { throw CoreError.loopNotFound }
      let focus = try Double.fetchOne(
        db,
        sql: "SELECT MAX(COALESCE(\"end\", ?)) FROM focusSession WHERE loopId = ?",
        arguments: [now, loopID.uuidString]
      )
      let seen = try Double.fetchOne(
        db,
        sql: """
          SELECT MAX(activity.lastSeen) FROM activity
          WHERE activity.identifier IN (SELECT identifier FROM anchor WHERE loopId = ?)
          """,
        arguments: [loopID.uuidString]
      )
      return [focus, seen, loop.editedAt].compactMap { $0 }.max()
    }
    return latest.map(Date.init(timeIntervalSince1970:))
  }

  // MARK: Helpers

  private static func sessions(_ sessions: [FocusSessionRecord], overlapping start: Double, _ end: Double, now: Double)
    -> [FocusSessionRecord]
  {
    sessions.filter { $0.start <= end && ($0.end ?? now) >= start }
  }

  /// Among Loops sharing an Anchor: the Focused one, then an Open one, then the most recently changed.
  private static func preferredOwner(_ candidates: [LoopRecord], focused: String?) -> LoopRecord? {
    func rank(_ loop: LoopRecord) -> Int {
      if loop.id == focused { return 2 }
      return loop.state == LoopState.open.rawValue ? 1 : 0
    }
    return candidates.max { lhs, rhs in
      rank(lhs) != rank(rhs) ? rank(lhs) < rank(rhs) : lhs.stateChangedAt < rhs.stateChangedAt
    }
  }

  /// Splits a stretch where a Focus starts or ends: pieces with the Focused Loop's id, or `nil`.
  private static func split(_ stretch: ActivityStretch, by sessions: [FocusSessionRecord], now: Double)
    -> [(start: Double, end: Double, focused: String?)]
  {
    let start = stretch.start.timeIntervalSince1970
    let end = stretch.end.timeIntervalSince1970
    let overlapping = Self.sessions(sessions, overlapping: start, end, now: now)
    if start == end { return [(start, end, overlapping.last?.loopId)] }
    var pieces: [(start: Double, end: Double, focused: String?)] = []
    var cursor = start
    for session in overlapping {
      let focusStart = max(session.start, cursor)
      let focusEnd = min(session.end ?? now, end)
      guard focusEnd > focusStart else { continue }
      if focusStart > cursor { pieces.append((cursor, focusStart, nil)) }
      pieces.append((focusStart, focusEnd, session.loopId))
      cursor = focusEnd
    }
    if cursor < end { pieces.append((cursor, end, nil)) }
    return pieces
  }

  private static func piece(
    _ stretch: ActivityStretch,
    _ start: Double,
    _ end: Double,
    _ loopID: UUID?,
    _ reason: AttributionReason,
    _ focusedLoopID: UUID?
  ) -> AttributedStretch {
    AttributedStretch(
      anchor: stretch.anchor,
      start: Date(timeIntervalSince1970: start),
      end: Date(timeIntervalSince1970: end),
      loopID: loopID,
      reason: reason,
      focusedLoopID: focusedLoopID
    )
  }
}
