public import Foundation
import GRDB

/// A summary of a day or week (see GLOSSARY.md).
public struct Recap: Hashable, Sendable {
  public struct LoopTime: Hashable, Sendable {
    public let loop: Loop
    public let time: TimeInterval
  }

  public struct PlaceTime: Hashable, Sendable {
    /// Where the time went: a website, or an app's bundle identifier.
    public let place: String
    public let time: TimeInterval
  }

  public struct TimelineEntry: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
      case focus(UUID)
      case unfocused
    }

    public let kind: Kind
    public let start: Date
    public let end: Date

    public var duration: TimeInterval { end.timeIntervalSince(start) }
  }

  public let period: DateInterval
  /// Loops Closed in the period, in the order they were Closed.
  public let closed: [Loop]
  /// Loops that got time in the period, most time first.
  public let movedForward: [LoopTime]
  /// Loops Captured in the period, oldest first.
  public let captured: [Loop]
  /// Everything that didn't go toward the Focused Loop.
  public let unfocusedTime: TimeInterval
  /// Unfocused time by where it was spent, most first.
  public let unfocusedBySource: [PlaceTime]
  /// Unfocused time that touched other Loops (their Anchors), most first.
  public let unfocusedByLoop: [LoopTime]
  /// Focus periods and Unfocused time outside any Focus, in order.
  public let timeline: [TimelineEntry]
  /// Titles of every Loop the timeline mentions.
  public let titles: [UUID: String]

  /// The Recap as Markdown, for pasting into notes. `name` turns a place into a readable name.
  public func markdown(name: (String) -> String = { $0 }) -> String {
    var lines: [String] = []
    func section(_ title: String, _ items: [String]) {
      guard !items.isEmpty else { return }
      lines.append("")
      lines.append("## \(title)")
      lines.append(contentsOf: items.map { "- \($0)" })
    }
    let start = period.start.formatted(date: .complete, time: .omitted)
    lines.append("# Recap: \(start)")
    section("Closed", closed.map(\.title))
    section("Moved forward", movedForward.map { "\($0.loop.title) (\(Self.format($0.time)))" })
    section("Captured", captured.map(\.title))
    lines.append("")
    lines.append("Unfocused time: \(Self.format(unfocusedTime))")
    section("Unfocused time by Source", unfocusedBySource.map { "\(name($0.place)): \(Self.format($0.time))" })
    section("Unfocused time in other Loops", unfocusedByLoop.map { "\($0.loop.title): \(Self.format($0.time))" })
    return lines.joined(separator: "\n") + "\n"
  }

  /// "1h 5m", "45m", "<1m".
  public static func format(_ time: TimeInterval) -> String {
    let minutes = Int((time / 60).rounded())
    if minutes < 1 { return "<1m" }
    let hours = minutes / 60
    return hours == 0 ? "\(minutes)m" : "\(hours)h \(minutes % 60)m"
  }
}

extension Anchor {
  /// Where the work lives: the website for web pages, the app's bundle identifier otherwise.
  public var place: String {
    if identifier.hasPrefix("web:") {
      return String(identifier.dropFirst(4).prefix { $0 != "/" && $0 != "?" })
    }
    return source.bundleID
  }
}

extension Core {
  /// The Recap of the calendar day containing `day`.
  public func recap(day: Date) throws -> Recap {
    let start = calendar.startOfDay(for: day)
    let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
    return try recap(DateInterval(start: start, end: end))
  }

  /// The Recap of the calendar week containing `date`.
  public func recap(weekOf date: Date) throws -> Recap {
    let week =
      calendar.dateInterval(of: .weekOfYear, for: date)
      ?? DateInterval(start: calendar.startOfDay(for: date), duration: 7 * 86_400)
    return try recap(week)
  }

  private func recap(_ period: DateInterval) throws -> Recap {
    let lower = period.start.timeIntervalSince1970
    let upper = period.end.timeIntervalSince1970
    let now = time.now.timeIntervalSince1970
    let attributed = try attributedActivity(from: period.start, to: period.end)

    let (closed, captured, sessions, loops) = try database.writer.read { db in
      let closedIDs = try String.fetchAll(
        db,
        sql: "SELECT loopId FROM loopEvent WHERE change = ? AND at >= ? AND at < ? ORDER BY at, id",
        arguments: [LoopChange.closed.rawValue, lower, upper]
      )
      let captured =
        try LoopRecord
        .filter(Column("capturedAt") >= lower && Column("capturedAt") < upper)
        .order(Column("capturedAt"), Column.rowID)
        .fetchAll(db)
        .map(\.loop)
      let sessions =
        try FocusSessionRecord
        .filter(Column("start") < upper)
        .filter(Column("end") == nil || Column("end") > lower)
        .order(Column("start"))
        .fetchAll(db)
      let loops = Dictionary(uniqueKeysWithValues: try LoopRecord.fetchAll(db).map { ($0.id, $0.loop) })
      return (closedIDs.compactMap { loops[$0] }, captured, sessions, loops)
    }
    func loop(_ id: UUID?) -> Loop? { id.flatMap { loops[$0.uuidString] } }

    let byLoop = Dictionary(grouping: attributed.filter { $0.loopID != nil }, by: \.loopID)
    let movedForward = byLoop.compactMap { id, pieces in
      loop(id).map { Recap.LoopTime(loop: $0, time: pieces.reduce(0) { $0 + $1.duration }) }
    }
    let unfocused = attributed.filter(\.isUnfocusedTime)
    let bySource = Dictionary(grouping: unfocused, by: \.anchor.place).map { place, pieces in
      Recap.PlaceTime(place: place, time: pieces.reduce(0) { $0 + $1.duration })
    }
    let unfocusedLoops = Dictionary(grouping: unfocused.filter { $0.loopID != nil }, by: \.loopID).compactMap {
      id,
      pieces in
      loop(id).map { Recap.LoopTime(loop: $0, time: pieces.reduce(0) { $0 + $1.duration }) }
    }

    var timeline = sessions.compactMap { session -> Recap.TimelineEntry? in
      guard let id = UUID(uuidString: session.loopId) else { return nil }
      return Recap.TimelineEntry(
        kind: .focus(id),
        start: Date(timeIntervalSince1970: max(session.start, lower)),
        end: Date(timeIntervalSince1970: min(session.end ?? now, upper))
      )
    }
    for piece in unfocused where piece.focusedLoopID == nil && piece.duration > 0 {
      if let last = timeline.last, last.kind == .unfocused, piece.start.timeIntervalSince(last.end) <= 120 {
        timeline[timeline.count - 1] = Recap.TimelineEntry(kind: .unfocused, start: last.start, end: piece.end)
      } else {
        timeline.append(Recap.TimelineEntry(kind: .unfocused, start: piece.start, end: piece.end))
      }
    }
    timeline.sort { $0.start < $1.start }

    return Recap(
      period: period,
      closed: closed,
      movedForward: movedForward.sorted(by: Self.mostTime),
      captured: captured,
      unfocusedTime: unfocused.reduce(0) { $0 + $1.duration },
      unfocusedBySource: bySource.sorted { $0.time != $1.time ? $0.time > $1.time : $0.place < $1.place },
      unfocusedByLoop: unfocusedLoops.sorted(by: Self.mostTime),
      timeline: timeline,
      titles: loops.reduce(into: [:]) { result, entry in result[entry.value.id] = entry.value.title }
    )
  }

  private static func mostTime(_ lhs: Recap.LoopTime, _ rhs: Recap.LoopTime) -> Bool {
    lhs.time != rhs.time ? lhs.time > rhs.time : lhs.loop.title < rhs.loop.title
  }
}
