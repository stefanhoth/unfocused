import Foundation
import Testing
import UnfocusedCore

@Suite("Loop lifecycle")
struct LifecycleTests {
  @Test("Closing a Loop removes it from the Open Loops")
  func close() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Send the invoice")

    try core.close(loop.id)

    #expect(try core.openLoops().isEmpty)
    #expect(try core.loops(in: .closed).map(\.id) == [loop.id])
  }

  @Test("Dropping a Loop removes it from the Open Loops")
  func drop() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Learn Rust")

    try core.drop(loop.id)

    #expect(try core.openLoops().isEmpty)
    #expect(try core.loops(in: .dropped).map(\.id) == [loop.id])
  }

  @Test("a Closed or Dropped Loop can be reopened")
  func reopen() throws {
    let (core, _) = try makeCore()
    let closed = try core.capture(title: "Contract")
    let dropped = try core.capture(title: "Side project")
    try core.close(closed.id)
    try core.drop(dropped.id)

    try core.reopen(closed.id)
    try core.reopen(dropped.id)

    #expect(Set(try core.openLoops().map(\.id)) == [closed.id, dropped.id])
  }

  @Test("only valid state changes are allowed")
  func invalidChanges() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Something")

    #expect(throws: CoreError.invalidStateChange) { try core.reopen(loop.id) }
    try core.close(loop.id)
    #expect(throws: CoreError.invalidStateChange) { try core.close(loop.id) }
    #expect(throws: CoreError.invalidStateChange) { try core.drop(loop.id) }
    #expect(throws: CoreError.loopNotFound) { try core.close(UUID()) }
  }

  @Test("Closing or Dropping the Focused Loop ends the Focus")
  func endsFocus() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Focused one")
    try core.focus(loop.id)
    time.advance(by: .minutes(15))

    try core.close(loop.id)

    #expect(try core.focusedLoop() == nil)
    #expect(try core.focusSessions(for: loop.id).map(\.duration) == [.minutes(15)])
  }

  @Test("a Loop that isn't Open can't be Focused")
  func focusNeedsOpen() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Done already")
    try core.close(loop.id)

    #expect(throws: CoreError.loopNotOpen) { try core.focus(loop.id) }
  }

  @Test("Closed Loops are listed most recently Closed first")
  func closedOrder() throws {
    let (core, time) = try makeCore()
    let first = try core.capture(title: "First")
    let second = try core.capture(title: "Second")
    try core.close(second.id)
    time.advance(by: .minutes(1))
    try core.close(first.id)

    #expect(try core.loops(in: .closed).map(\.id) == [first.id, second.id])
  }
}

@Suite("Loop history")
struct HistoryTests {
  @Test("records Capture and every state change with its time")
  func stateChanges() throws {
    let (core, time) = try makeCore()
    let start = time.now
    let loop = try core.capture(title: "Contract")
    time.advance(by: .hours(1))
    try core.close(loop.id)
    time.advance(by: .hours(1))
    try core.reopen(loop.id)
    time.advance(by: .hours(1))
    try core.drop(loop.id)

    let history = try core.history(for: loop.id)

    #expect(history.map(\.change) == [.captured, .closed, .reopened, .dropped])
    #expect(history.map(\.at) == [0, 1, 2, 3].map { start.addingTimeInterval(.hours($0)) })
  }

  @Test("an unknown Loop has no history")
  func unknown() throws {
    let (core, _) = try makeCore()
    #expect(try core.history(for: UUID()).isEmpty)
  }
}
