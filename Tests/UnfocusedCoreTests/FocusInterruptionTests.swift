import Foundation
import Testing
import UnfocusedCore

private func page(_ path: String) -> Anchor {
  guard let anchor = Anchor.webPage(url: "https://example.com/\(path)", title: path, source: .safari) else {
    preconditionFailure("test URL must be valid")
  }
  return anchor
}

@Suite("Focus interruptions")
struct FocusInterruptionTests {
  @Test("sleep ends Focus at the time it happened and remembers the Loop for the return prompt")
  func sleepEndsFocus() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec")
    try core.focus(loop.id)
    time.advance(by: .minutes(20))
    let slept = time.now

    try core.interruptFocus(at: slept, because: .sleep)
    time.advance(by: .hours(8))

    #expect(try core.focusedLoop() == nil)
    #expect(try core.focusSessions(for: loop.id).map(\.end) == [slept])
    #expect(try core.interruptedFocus()?.loop.id == loop.id)
    #expect(try core.interruptedFocus()?.reason == .sleep)
  }

  @Test("idle and lock pause Focus, and the paused time isn't attributed to the Loop")
  func idlePausesFocus() throws {
    let (core, time) = try makeCore()
    let start = time.now
    let loop = try core.capture(title: "Spec")
    try core.focus(loop.id)
    try core.recordActivity(page("random"))
    for _ in 0..<10 {
      time.advance(by: .minutes(1))
      try core.recordActivity(page("random"))
    }
    let idleSince = time.now

    time.advance(by: .minutes(40))
    try core.interruptFocus(at: idleSince, because: .idle)
    try core.recordActivity(page("random"))
    time.advance(by: .minutes(1))
    try core.recordActivity(page("random"))

    #expect(try core.interruptedFocus()?.reason == .idle)
    #expect(try core.timeSpent(on: loop.id, from: start, to: time.now) == .minutes(10))
  }

  @Test("Continue Focuses the Loop again from now and clears the prompt")
  func continueFocus() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec")
    try core.focus(loop.id)
    try core.interruptFocus(at: time.now, because: .idle)
    time.advance(by: .hours(1))

    try core.continueInterruptedFocus()

    #expect(try core.focusedLoop()?.id == loop.id)
    #expect(try core.focusSessions(for: loop.id).count == 2)
    #expect(try core.focusSessions(for: loop.id).last?.start == time.now)
    #expect(try core.interruptedFocus() == nil)
  }

  @Test("closing, letting go, unfocusing or Focusing something else clears the prompt")
  func otherAnswersClear() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec")
    let other = try core.capture(title: "Other")

    try core.focus(loop.id)
    try core.interruptFocus(at: time.now, because: .sleep)
    try core.close(loop.id)
    #expect(try core.interruptedFocus() == nil)

    try core.reopen(loop.id)
    try core.focus(loop.id)
    try core.interruptFocus(at: time.now, because: .sleep)
    try core.letGo(loop.id)
    #expect(try core.interruptedFocus() == nil)

    try core.reopen(loop.id)
    try core.focus(loop.id)
    try core.interruptFocus(at: time.now, because: .sleep)
    try core.unfocus()
    #expect(try core.interruptedFocus() == nil)

    try core.focus(loop.id)
    try core.interruptFocus(at: time.now, because: .sleep)
    try core.focus(other.id)
    #expect(try core.interruptedFocus() == nil)
  }

  @Test("closing another Loop keeps the prompt")
  func otherLoopKeeps() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec")
    let other = try core.capture(title: "Other")
    try core.focus(loop.id)
    try core.interruptFocus(at: time.now, because: .idle)
    try core.close(other.id)
    #expect(try core.interruptedFocus()?.loop.id == loop.id)
  }

  @Test("without a Focus, an interruption changes nothing")
  func nothingFocused() throws {
    let (core, time) = try makeCore()
    try core.interruptFocus(at: time.now, because: .sleep)
    #expect(try core.interruptedFocus() == nil)
  }

  @Test("a second interruption keeps the first end time")
  func repeated() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec")
    try core.focus(loop.id)
    let first = time.now
    try core.interruptFocus(at: first, because: .idle)
    time.advance(by: .minutes(10))
    try core.interruptFocus(at: time.now, because: .sleep)

    #expect(try core.focusSessions(for: loop.id).map(\.end) == [first])
    #expect(try core.interruptedFocus()?.reason == .idle)
  }

  @Test("an interruption is never placed before the Focus started")
  func clampsToStart() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec")
    let focused = time.now
    try core.focus(loop.id)
    try core.interruptFocus(at: focused.addingTimeInterval(-.minutes(10)), because: .idle)
    #expect(try core.focusSessions(for: loop.id).map(\.end) == [focused])
  }

  @Test("the idle threshold defaults to 30 minutes and is configurable")
  func threshold() throws {
    let (core, _) = try makeCore()
    #expect(try core.focusIdleThreshold() == .minutes(30))
    try core.setFocusIdleThreshold(.minutes(10))
    #expect(try core.focusIdleThreshold() == .minutes(10))
    try core.setFocusIdleThreshold(0)
    #expect(try core.focusIdleThreshold() == .minutes(1))
  }

  @Test("a Focus left running while the app was gone ends at the last Activity seen during it")
  func staleFocusOnLaunch() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec")
    try core.focus(loop.id)
    try core.recordActivity(page("a"))
    time.advance(by: .minutes(1))
    try core.recordActivity(page("a"))
    let lastSeen = time.now
    time.advance(by: .hours(10))

    try core.endStaleFocus()

    #expect(try core.focusedLoop() == nil)
    #expect(try core.focusSessions(for: loop.id).map(\.end) == [lastSeen])
    #expect(try core.interruptedFocus()?.reason == .sleep)
  }

  @Test("a recent Focus survives an app restart")
  func freshFocusOnLaunch() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec")
    try core.focus(loop.id)
    try core.recordActivity(page("a"))
    time.advance(by: .minutes(2))

    try core.endStaleFocus()

    #expect(try core.focusedLoop()?.id == loop.id)
  }
}
