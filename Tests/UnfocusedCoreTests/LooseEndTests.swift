import Foundation
import Testing
import UnfocusedCore

private func page(_ path: String) -> Anchor {
  guard let anchor = Anchor.webPage(url: "https://example.com/\(path)", title: path, source: .safari) else {
    preconditionFailure("test URL must be valid")
  }
  return anchor
}

/// Moves to the next day and uses the Mac for a few minutes, somewhere unrelated.
private func activeDay(_ core: Core, _ time: TestTime) throws {
  time.advance(by: .days(1))
  try core.recordActivity(page("elsewhere"))
  time.advance(by: .minutes(1))
  try core.recordActivity(page("elsewhere"))
}

/// Moves to the next day without using the Mac (a weekend, a holiday).
private func dayOff(_ time: TestTime) {
  time.advance(by: .days(1))
}

@Suite("Loose Ends")
struct LooseEndTests {
  @Test("a freshly captured Loop isn't aging")
  func fresh() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Spec")
    let aging = try #require(try core.aging(of: loop.id))
    #expect(aging.activeDaysWithoutEngagement == 0)
    #expect(!aging.isLooseEnd)
    #expect(aging.progress == 0)
  }

  @Test("an Open Loop becomes a Loose End after 3 active days without Engagement")
  func threeActiveDays() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec")

    try activeDay(core, time)
    try activeDay(core, time)
    #expect(try core.aging(of: loop.id)?.isLooseEnd == false)

    try activeDay(core, time)
    #expect(try core.aging(of: loop.id)?.isLooseEnd == true)
    #expect(try core.looseEnds().map(\.loop.id) == [loop.id])
  }

  @Test("days without any Activity (weekends, holidays) don't count")
  func daysOffDontCount() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec")

    try activeDay(core, time)
    dayOff(time)
    dayOff(time)
    dayOff(time)
    try activeDay(core, time)
    #expect(try core.aging(of: loop.id)?.activeDaysWithoutEngagement == 2)
    #expect(try core.aging(of: loop.id)?.isLooseEnd == false)
  }

  @Test("using the Mac on the day of capture doesn't count")
  func sameDay() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec")
    time.advance(by: .hours(2))
    try core.recordActivity(page("elsewhere"))
    #expect(try core.aging(of: loop.id)?.activeDaysWithoutEngagement == 0)
  }

  @Test("Engagement restarts the countdown")
  func engagementResets() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec")
    try activeDay(core, time)
    try activeDay(core, time)

    try core.setWhereILeftOff(loop.id, to: "section 2")
    try activeDay(core, time)

    #expect(try core.aging(of: loop.id)?.activeDaysWithoutEngagement == 1)
  }

  @Test("aging shows gradually on the way to a Loose End")
  func gradual() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec")
    try activeDay(core, time)
    #expect(try core.aging(of: loop.id)?.progress == 1.0 / 3)
    try activeDay(core, time)
    try activeDay(core, time)
    try activeDay(core, time)
    #expect(try core.aging(of: loop.id)?.progress == 1)
  }

  @Test("the threshold is configurable")
  func threshold() throws {
    let (core, time) = try makeCore()
    #expect(try core.looseEndThreshold() == 3)
    try core.setLooseEndThreshold(5)
    let loop = try core.capture(title: "Spec")
    for _ in 0..<4 { try activeDay(core, time) }
    #expect(try core.aging(of: loop.id)?.isLooseEnd == false)
    try activeDay(core, time)
    #expect(try core.aging(of: loop.id)?.isLooseEnd == true)

    try core.setLooseEndThreshold(0)
    #expect(try core.looseEndThreshold() == 1)
  }

  @Test("Waiting Loops age the same way and name who to follow up with")
  func waiting() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Contract from @Ada", directions: ["Ada": .waiting])
    for _ in 0..<3 { try activeDay(core, time) }
    let aging = try #require(try core.aging(of: loop.id))
    #expect(aging.isLooseEnd)
    #expect(aging.followUp.map(\.name) == ["Ada"])
  }

  @Test("Owed People aren't follow-ups")
  func owed() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Review for @Ada")
    #expect(try core.aging(of: loop.id)?.followUp.isEmpty == true)
  }

  @Test("Loose Ends are ranked oldest first, and only Open Loops count")
  func ranking() throws {
    let (core, time) = try makeCore()
    let oldest = try core.capture(title: "Oldest")
    try activeDay(core, time)
    let middle = try core.capture(title: "Middle")
    let closed = try core.capture(title: "Closed")
    try core.close(closed.id)
    for _ in 0..<4 { try activeDay(core, time) }
    _ = try core.capture(title: "Fresh")

    #expect(try core.looseEnds().map(\.loop.id) == [oldest.id, middle.id])
    #expect(try core.aging(of: closed.id) == nil)
  }
}
