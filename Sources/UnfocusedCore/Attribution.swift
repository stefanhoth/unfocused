public import Foundation
import GRDB

/// Why a piece of Activity counts toward a Loop (or toward none).
public enum AttributionReason: String, Sendable, CaseIterable {
  /// It happened in one of the Loop's Anchors.
  case anchor
  /// It happened elsewhere while the Loop was Focused.
  case focus
  /// It matched no Loop: Unfocused time.
  case unfocused
}

/// A piece of Activity with the Loop it counts toward.
public struct AttributedStretch: Hashable, Sendable {
  public let anchor: Anchor
  public let start: Date
  public let end: Date
  /// `nil` for Unfocused time.
  public let loopID: UUID?
  public let reason: AttributionReason

  public init(anchor: Anchor, start: Date, end: Date, loopID: UUID?, reason: AttributionReason) {
    self.anchor = anchor
    self.start = start
    self.end = end
    self.loopID = loopID
    self.reason = reason
  }

  public var duration: TimeInterval { end.timeIntervalSince(start) }
}

extension Core {
  // MARK: Attribution

  /// Activity between `from` and `to`, each piece attributed by rule:
  /// time in a Loop's Anchor goes to that Loop, other time during a Focus goes to the Focused Loop,
  /// everything else is Unfocused time. Stretches are split where a Focus starts or ends.
  public func attributedActivity(from: Date, to: Date) throws -> [AttributedStretch] {
    let stretches = try activity(from: from, to: to)
    guard !stretches.isEmpty else { return [] }
    let now = time.now.timeIntervalSince1970
    let (owners, sessions) = try database.writer.read { db in
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
      return (owners, sessions)
    }

    return stretches.flatMap { stretch -> [AttributedStretch] in
      let start = stretch.start.timeIntervalSince1970
      let end = stretch.end.timeIntervalSince1970
      let focused = Set(Self.sessions(sessions, overlapping: start, end, now: now).map(\.loopId))
      if let owner = Self.preferredOwner(owners[stretch.anchor.identifier] ?? [], focused: focused) {
        return [Self.piece(stretch, start, end, UUID(uuidString: owner.id), .anchor)]
      }
      return Self.split(stretch, start, end, by: sessions, now: now)
    }
  }

  /// Total Unfocused time between `from` and `to`.
  public func unfocusedTime(from: Date, to: Date) throws -> TimeInterval {
    try attributedActivity(from: from, to: to).filter { $0.reason == .unfocused }.reduce(0) { $0 + $1.duration }
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
  private static func preferredOwner(_ candidates: [LoopRecord], focused: Set<String>) -> LoopRecord? {
    func rank(_ loop: LoopRecord) -> Int {
      if focused.contains(loop.id) { return 2 }
      return loop.state == LoopState.open.rawValue ? 1 : 0
    }
    return candidates.max { lhs, rhs in
      rank(lhs) != rank(rhs) ? rank(lhs) < rank(rhs) : lhs.stateChangedAt < rhs.stateChangedAt
    }
  }

  /// Splits a stretch outside any Anchor into Focus pieces and Unfocused pieces.
  private static func split(
    _ stretch: ActivityStretch,
    _ start: Double,
    _ end: Double,
    by sessions: [FocusSessionRecord],
    now: Double
  ) -> [AttributedStretch] {
    let overlapping = Self.sessions(sessions, overlapping: start, end, now: now)
    if start == end {
      let loop = overlapping.last.flatMap { UUID(uuidString: $0.loopId) }
      return [piece(stretch, start, end, loop, loop == nil ? .unfocused : .focus)]
    }
    var pieces: [AttributedStretch] = []
    var cursor = start
    for session in overlapping {
      let focusStart = max(session.start, cursor)
      let focusEnd = min(session.end ?? now, end)
      guard focusEnd > focusStart else { continue }
      if focusStart > cursor { pieces.append(piece(stretch, cursor, focusStart, nil, .unfocused)) }
      pieces.append(piece(stretch, focusStart, focusEnd, UUID(uuidString: session.loopId), .focus))
      cursor = focusEnd
    }
    if cursor < end { pieces.append(piece(stretch, cursor, end, nil, .unfocused)) }
    return pieces
  }

  private static func piece(
    _ stretch: ActivityStretch,
    _ start: Double,
    _ end: Double,
    _ loopID: UUID?,
    _ reason: AttributionReason
  ) -> AttributedStretch {
    AttributedStretch(
      anchor: stretch.anchor,
      start: Date(timeIntervalSince1970: start),
      end: Date(timeIntervalSince1970: end),
      loopID: loopID,
      reason: reason
    )
  }
}
