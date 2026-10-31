import Foundation
import Testing
import UnfocusedCore

private func page(_ host: String, _ path: String) -> Anchor {
  guard let anchor = Anchor.webPage(url: "https://\(host)/\(path)", title: path, source: .safari) else {
    preconditionFailure("test URL must be valid")
  }
  return anchor
}

private func spend(_ minutes: Int, on anchor: Anchor, _ core: Core, _ time: TestTime) throws {
  try core.recordActivity(anchor)
  for _ in 0..<minutes {
    time.advance(by: .minutes(1))
    try core.recordActivity(anchor)
  }
}

@Suite("Recap")
struct RecapTests {
  /// A day: capture two Loops, work on one, drift, close one. The clock starts at 08:00 UTC.
  private func day() throws -> (Core, TestTime, spec: Loop, review: Loop) {
    let (core, time) = try makeCore()
    let spec = try core.capture(title: "Write spec", anchor: page("docs.example", "spec"))
    let review = try core.capture(title: "Review PR", anchor: page("github.com", "pr/1"))
    try core.focus(spec.id)
    try spend(30, on: page("docs.example", "spec"), core, time)  // toward the Focused Loop
    try spend(10, on: page("news.example", "today"), core, time)  // fallback: toward the Focused Loop
    try spend(5, on: page("github.com", "pr/1"), core, time)  // another Loop's Anchor: Unfocused
    try core.unfocus()
    try spend(15, on: page("news.example", "today"), core, time)  // nothing Focused: Unfocused
    try core.close(spec.id)
    return (core, time, spec, review)
  }

  @Test("a daily Recap lists Loops Closed, moved forward and Captured")
  func loops() throws {
    let (core, time, spec, review) = try day()
    let recap = try core.recap(day: time.now)

    #expect(recap.closed.map(\.id) == [spec.id])
    #expect(recap.captured.map(\.id) == [spec.id, review.id])
    #expect(recap.movedForward.map(\.loop.id) == [spec.id, review.id])
    #expect(recap.movedForward.map(\.time) == [.minutes(40), .minutes(5)])
  }

  @Test("Unfocused time is one number, broken down by Source and by the Loops it touched")
  func unfocused() throws {
    let (core, time, _, review) = try day()
    let recap = try core.recap(day: time.now)

    #expect(recap.unfocusedTime == .minutes(20))
    #expect(recap.unfocusedBySource.map(\.place) == ["news.example", "github.com"])
    #expect(recap.unfocusedBySource.map(\.time) == [.minutes(15), .minutes(5)])
    #expect(recap.unfocusedByLoop.map(\.loop.id) == [review.id])
    #expect(recap.unfocusedByLoop.map(\.time) == [.minutes(5)])
  }

  @Test("the timeline shows Focus periods and Unfocused time in order")
  func timeline() throws {
    let (core, time, spec, _) = try day()
    let recap = try core.recap(day: time.now)

    #expect(recap.timeline.map(\.kind) == [.focus(spec.id), .unfocused])
    #expect(recap.timeline.map(\.duration) == [.minutes(45), .minutes(15)])
  }

  @Test("a weekly Recap covers the whole calendar week")
  func week() throws {
    let (core, time, spec, _) = try day()
    time.advance(by: .days(1))
    let next = try core.capture(title: "Plan offsite")
    let weekly = try core.recap(weekOf: time.now)
    let daily = try core.recap(day: time.now)

    #expect(weekly.captured.count == 3)
    #expect(weekly.closed.map(\.id) == [spec.id])
    #expect(daily.captured.map(\.id) == [next.id])
    #expect(daily.closed.isEmpty)
  }

  @Test("Copy as Markdown includes every figure")
  func markdown() throws {
    let (core, time, _, _) = try day()
    let markdown = try core.recap(day: time.now).markdown()

    #expect(markdown.contains("## Closed"))
    #expect(markdown.contains("- Write spec"))
    #expect(markdown.contains("## Moved forward"))
    #expect(markdown.contains("- Review PR (5m)"))
    #expect(markdown.contains("## Captured"))
    #expect(markdown.contains("Unfocused time: 20m"))
    #expect(markdown.contains("- news.example: 15m"))
  }
}
