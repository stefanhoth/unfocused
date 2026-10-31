import Foundation
import Testing
import UnfocusedCore

private func page(_ path: String) -> Anchor {
  guard let anchor = Anchor.webPage(url: "https://example.com/\(path)", title: path, source: .safari) else {
    preconditionFailure("test URL must be valid")
  }
  return anchor
}

/// Stays on `anchor` for `minutes`, observed once a minute.
private func dwell(_ minutes: Int, on anchor: Anchor, _ core: Core, _ time: TestTime) throws {
  try core.recordActivity(anchor)
  for _ in 0..<minutes {
    time.advance(by: .minutes(1))
    try core.recordActivity(anchor)
  }
}

@Suite("Silent switch")
struct SilentSwitchTests {
  @Test("about 3 minutes in another Loop's Anchor suggests switching Focus to it")
  func suggests() throws {
    let (core, time) = try makeCore()
    let spec = try core.capture(title: "Spec")
    let review = try core.capture(title: "Review", anchor: page("review"))
    try core.focus(spec.id)

    try dwell(2, on: page("review"), core, time)
    #expect(try core.silentSwitchSuggestion() == nil)

    time.advance(by: .minutes(1))
    try core.recordActivity(page("review"))
    #expect(try core.silentSwitchSuggestion()?.id == review.id)
  }

  @Test("it also suggests a Loop when nothing is Focused")
  func unfocused() throws {
    let (core, time) = try makeCore()
    let review = try core.capture(title: "Review", anchor: page("review"))
    try dwell(3, on: page("review"), core, time)
    #expect(try core.silentSwitchSuggestion()?.id == review.id)
  }

  @Test("time in the Focused Loop's own Anchor suggests nothing")
  func ownAnchor() throws {
    let (core, time) = try makeCore()
    let spec = try core.capture(title: "Spec", anchor: page("spec"))
    try core.focus(spec.id)
    try dwell(5, on: page("spec"), core, time)
    #expect(try core.silentSwitchSuggestion() == nil)
  }

  @Test("Activity outside known Anchors never triggers it")
  func unknown() throws {
    let (core, time) = try makeCore()
    let spec = try core.capture(title: "Spec")
    try core.focus(spec.id)
    try dwell(10, on: page("random"), core, time)
    #expect(try core.silentSwitchSuggestion() == nil)
  }

  @Test("Anchors of Closed or Dropped Loops don't trigger it")
  func notOpen() throws {
    let (core, time) = try makeCore()
    let old = try core.capture(title: "Old", anchor: page("old"))
    try core.close(old.id)
    try dwell(5, on: page("old"), core, time)
    #expect(try core.silentSwitchSuggestion() == nil)
  }

  @Test("the dwell must be continuous: leaving restarts it")
  func continuous() throws {
    let (core, time) = try makeCore()
    _ = try core.capture(title: "Review", anchor: page("review"))
    try dwell(2, on: page("review"), core, time)
    try dwell(1, on: page("random"), core, time)
    try dwell(2, on: page("review"), core, time)
    #expect(try core.silentSwitchSuggestion() == nil)
  }

  @Test("after leaving the Anchor, nothing is suggested")
  func leftAgain() throws {
    let (core, time) = try makeCore()
    _ = try core.capture(title: "Review", anchor: page("review"))
    try dwell(4, on: page("review"), core, time)
    try core.recordActivity(page("random"))
    #expect(try core.silentSwitchSuggestion() == nil)
  }

  @Test("Not now suppresses it for the rest of the current Focus")
  func notNow() throws {
    let (core, time) = try makeCore()
    let spec = try core.capture(title: "Spec")
    let review = try core.capture(title: "Review", anchor: page("review"))
    let other = try core.capture(title: "Other", anchor: page("other"))
    try core.focus(spec.id)
    try dwell(3, on: page("review"), core, time)

    try core.notNowSilentSwitch()
    #expect(try core.silentSwitchSuggestion() == nil)
    try dwell(3, on: page("other"), core, time)
    #expect(try core.silentSwitchSuggestion() == nil)

    try core.focus(review.id)
    try dwell(3, on: page("other"), core, time)
    #expect(try core.silentSwitchSuggestion()?.id == other.id)
  }
}
