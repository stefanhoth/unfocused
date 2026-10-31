import Foundation
import Testing
import UnfocusedCore

private func page(_ path: String) -> Anchor {
  guard let anchor = Anchor.webPage(url: "https://example.com/\(path)", title: path, source: .safari) else {
    preconditionFailure("test URL must be valid")
  }
  return anchor
}

/// Records `minutes` of Activity on `anchor`, observed once a minute like the app does.
private func spend(_ minutes: Int, on anchor: Anchor, _ core: Core, _ time: TestTime) throws {
  try core.recordActivity(anchor)
  for _ in 0..<minutes {
    time.advance(by: .minutes(1))
    try core.recordActivity(anchor)
  }
}

@Suite("Attribution")
struct AttributionTests {
  @Test("time in a Loop's Anchor goes to that Loop")
  func anchorMatch() throws {
    let (core, time) = try makeCore()
    let start = time.now
    let loop = try core.capture(title: "Spec", anchor: page("spec"))

    try spend(10, on: page("spec"), core, time)

    let attributed = try core.attributedActivity(from: start, to: time.now)
    #expect(attributed.count == 1)
    #expect(attributed.first?.loopID == loop.id)
    #expect(attributed.first?.reason == .anchor)
    #expect(attributed.first?.duration == .minutes(10))
  }

  @Test("time in a Loop's Anchor goes to that Loop even while another Loop is Focused")
  func anchorBeatsFocus() throws {
    let (core, time) = try makeCore()
    let start = time.now
    let spec = try core.capture(title: "Spec", anchor: page("spec"))
    let review = try core.capture(title: "Review")
    try core.focus(review.id)

    try spend(5, on: page("spec"), core, time)

    let attributed = try core.attributedActivity(from: start, to: time.now)
    #expect(attributed.map(\.loopID) == [spec.id])
    #expect(attributed.map(\.reason) == [.anchor])
  }

  @Test("other time during Focus goes to the Focused Loop")
  func focusFallback() throws {
    let (core, time) = try makeCore()
    let start = time.now
    let loop = try core.capture(title: "Spec")
    try core.focus(loop.id)

    try spend(5, on: page("random"), core, time)

    let attributed = try core.attributedActivity(from: start, to: time.now)
    #expect(attributed.map(\.loopID) == [loop.id])
    #expect(attributed.map(\.reason) == [.focus])
  }

  @Test("everything else is Unfocused time")
  func unfocused() throws {
    let (core, time) = try makeCore()
    let start = time.now
    _ = try core.capture(title: "Spec", anchor: page("spec"))

    try spend(7, on: page("random"), core, time)

    let attributed = try core.attributedActivity(from: start, to: time.now)
    #expect(attributed.map(\.loopID) == [nil])
    #expect(attributed.map(\.reason) == [.unfocused])
    #expect(try core.unfocusedTime(from: start, to: time.now) == .minutes(7))
  }

  @Test("Unfocused time is everything that didn't go toward the Focused Loop")
  func unfocusedTimeDefinition() throws {
    let (core, time) = try makeCore()
    let start = time.now
    let spec = try core.capture(title: "Spec", anchor: page("spec"))
    let review = try core.capture(title: "Review", anchor: page("review"))

    try spend(2, on: page("review"), core, time)  // nothing Focused, in a Loop's Anchor
    try core.focus(spec.id)
    try spend(3, on: page("spec"), core, time)  // toward the Focused Loop
    try spend(4, on: page("notes"), core, time)  // toward the Focused Loop, by fallback
    try spend(5, on: page("review"), core, time)  // another Loop's Anchor during Focus

    let attributed = try core.attributedActivity(from: start, to: time.now)
    #expect(attributed.map(\.loopID) == [review.id, spec.id, spec.id, review.id])
    #expect(attributed.map(\.isUnfocusedTime) == [true, false, false, true])
    #expect(try core.unfocusedTime(from: start, to: time.now) == .minutes(7))
  }

  @Test("a stretch in an Anchor that spans the start of a Focus is split too")
  func anchorSplitAtFocus() throws {
    let (core, time) = try makeCore()
    let start = time.now
    let spec = try core.capture(title: "Spec", anchor: page("spec"))
    try spend(2, on: page("spec"), core, time)
    try core.focus(spec.id)
    for _ in 0..<3 {
      time.advance(by: .minutes(1))
      try core.recordActivity(page("spec"))
    }

    let attributed = try core.attributedActivity(from: start, to: time.now)
    #expect(attributed.map(\.duration) == [.minutes(2), .minutes(3)])
    #expect(attributed.map(\.isUnfocusedTime) == [true, false])
  }

  @Test("a stretch that spans the start of a Focus is split at the boundary")
  func splitAtFocus() throws {
    let (core, time) = try makeCore()
    let start = time.now
    let loop = try core.capture(title: "Spec")

    try spend(4, on: page("random"), core, time)
    try core.focus(loop.id)
    for _ in 0..<6 {
      time.advance(by: .minutes(1))
      try core.recordActivity(page("random"))
    }
    try core.unfocus()
    for _ in 0..<2 {
      time.advance(by: .minutes(1))
      try core.recordActivity(page("random"))
    }

    let attributed = try core.attributedActivity(from: start, to: time.now)
    #expect(attributed.map(\.reason) == [.unfocused, .focus, .unfocused])
    #expect(attributed.map(\.duration) == [.minutes(4), .minutes(6), .minutes(2)])
    #expect(attributed[1].loopID == loop.id)
  }

  @Test("an Anchor shared by an Open and a Closed Loop goes to the Open one")
  func sharedAnchorPrefersOpen() throws {
    let (core, time) = try makeCore()
    let old = try core.capture(title: "Old", anchor: page("doc"))
    try core.close(old.id)
    time.advance(by: .minutes(1))
    let current = try core.capture(title: "Current", anchor: page("doc"))
    let start = time.now

    try spend(3, on: page("doc"), core, time)

    #expect(try core.attributedActivity(from: start, to: time.now).map(\.loopID) == [current.id])
  }

  @Test("a Loop's work log shows where and why time was attributed to it")
  func workLog() throws {
    let (core, time) = try makeCore()
    let start = time.now
    let loop = try core.capture(title: "Spec", anchor: page("spec"))
    try core.focus(loop.id)

    try spend(3, on: page("spec"), core, time)
    try spend(2, on: page("notes"), core, time)
    try core.unfocus()
    try spend(4, on: page("random"), core, time)

    let log = try core.workLog(for: loop.id, from: start, to: time.now)
    #expect(log.map(\.anchor.title) == ["spec", "notes"])
    #expect(log.map(\.reason) == [.anchor, .focus])
    #expect(try core.timeSpent(on: loop.id, from: start, to: time.now) == .minutes(5))
  }
}

@Suite("Engagement")
struct EngagementTests {
  @Test("a Loop nobody touched has no Engagement")
  func none() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Spec")
    #expect(try core.lastEngagement(of: loop.id) == nil)
  }

  @Test("Focus is Engagement until it ends")
  func focus() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec")
    try core.focus(loop.id)
    time.advance(by: .minutes(30))
    #expect(try core.lastEngagement(of: loop.id) == time.now)

    try core.unfocus()
    let ended = time.now
    time.advance(by: .hours(3))
    #expect(try core.lastEngagement(of: loop.id) == ended)
  }

  @Test("being in one of a Loop's Anchors is Engagement")
  func anchorActivity() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec", anchor: page("spec"))
    time.advance(by: .days(1))
    try spend(2, on: page("spec"), core, time)
    let seen = time.now
    time.advance(by: .hours(1))

    #expect(try core.lastEngagement(of: loop.id) == seen)
  }

  @Test("editing a Loop is Engagement")
  func edit() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec")
    time.advance(by: .hours(2))
    try core.setWhereILeftOff(loop.id, to: "halfway through section 2")
    #expect(try core.lastEngagement(of: loop.id) == time.now)

    time.advance(by: .hours(2))
    try core.addAnchor(page("spec"), to: loop.id)
    #expect(try core.lastEngagement(of: loop.id) == time.now)

    time.advance(by: .hours(2))
    let person = try core.addPerson(named: "Ada")
    try core.involve(person.id, in: loop.id, as: .waiting)
    #expect(try core.lastEngagement(of: loop.id) == time.now)
  }

  @Test("Activity elsewhere isn't Engagement")
  func elsewhere() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec", anchor: page("spec"))
    try spend(5, on: page("random"), core, time)
    #expect(try core.lastEngagement(of: loop.id) == nil)
  }
}
