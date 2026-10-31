public import Foundation
import GRDB

/// How far an Open Loop has drifted toward becoming a Loose End.
public struct LoopAging: Hashable, Sendable {
  public let loop: Loop
  /// Days the user used the Mac since the Loop was last worked on (or captured).
  public let activeDaysWithoutEngagement: Int
  /// Active days without Engagement that make a Loose End.
  public let threshold: Int
  /// People this Loop is Waiting on: "Follow up with …?"
  public let followUp: [Person]

  public init(loop: Loop, activeDaysWithoutEngagement: Int, threshold: Int, followUp: [Person]) {
    self.loop = loop
    self.activeDaysWithoutEngagement = activeDaysWithoutEngagement
    self.threshold = threshold
    self.followUp = followUp
  }

  public var isLooseEnd: Bool { activeDaysWithoutEngagement >= threshold }

  /// 0 when just worked on, 1 once it's a Loose End.
  public var progress: Double { min(1, Double(activeDaysWithoutEngagement) / Double(max(1, threshold))) }
}

extension Core {
  private static let looseEndThresholdSetting = "looseEndThresholdDays"

  /// Active days without Engagement before an Open Loop is a Loose End. Defaults to 3; at least 1.
  public func looseEndThreshold() throws -> Int {
    try database.setting(Self.looseEndThresholdSetting).flatMap(Int.init) ?? 3
  }

  public func setLooseEndThreshold(_ days: Int) throws {
    try database.setSetting(Self.looseEndThresholdSetting, to: String(max(1, days)))
  }

  /// How an Open Loop is aging; `nil` if the Loop isn't Open.
  public func aging(of loopID: UUID) throws -> LoopAging? {
    guard let loop = try loop(loopID), loop.state == .open else { return nil }
    return try aging(of: loop, activeDays: activeDays(), threshold: looseEndThreshold())
  }

  /// Every Open Loop with its aging, most aged first.
  public func agingOfOpenLoops() throws -> [LoopAging] {
    let days = try activeDays()
    let threshold = try looseEndThreshold()
    return try openLoops()
      .map { try aging(of: $0, activeDays: days, threshold: threshold) }
      .sorted { lhs, rhs in
        lhs.activeDaysWithoutEngagement != rhs.activeDaysWithoutEngagement
          ? lhs.activeDaysWithoutEngagement > rhs.activeDaysWithoutEngagement
          : lhs.loop.capturedAt < rhs.loop.capturedAt
      }
  }

  /// The Loose Ends, most aged first.
  public func looseEnds() throws -> [LoopAging] {
    try agingOfOpenLoops().filter(\.isLooseEnd)
  }

  // MARK: Helpers

  private func aging(of loop: Loop, activeDays: Set<Date>, threshold: Int) throws -> LoopAging {
    let since = calendar.startOfDay(for: try lastEngagement(of: loop.id) ?? loop.capturedAt)
    let followUp = try people(of: loop.id).filter { $0.direction == .waiting }.map(\.person)
    return LoopAging(
      loop: loop,
      activeDaysWithoutEngagement: activeDays.count { $0 > since },
      threshold: threshold,
      followUp: followUp
    )
  }

  /// The start of every day with recorded Activity.
  private func activeDays() throws -> Set<Date> {
    let rows = try database.writer.read { db in
      try Row.fetchAll(db, sql: "SELECT start, lastSeen FROM activity")
    }
    var days = Set<Date>()
    for row in rows {
      let start: Double = row["start"]
      let lastSeen: Double = row["lastSeen"]
      days.insert(calendar.startOfDay(for: Date(timeIntervalSince1970: start)))
      days.insert(calendar.startOfDay(for: Date(timeIntervalSince1970: lastSeen)))
    }
    return days
  }
}
