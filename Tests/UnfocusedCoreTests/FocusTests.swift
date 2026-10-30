import Foundation
import Testing
import UnfocusedCore

@Suite("Focus")
struct FocusTests {
  @Test("nothing is Focused at first")
  func unfocusedAtStart() throws {
    let (core, _) = try makeCore()
    _ = try core.capture(title: "Something")

    #expect(try core.focusedLoop() == nil)
  }

  @Test("Focusing a Loop makes it the Focused Loop")
  func focuses() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Pricing proposal")

    try core.focus(loop.id)

    #expect(try core.focusedLoop()?.id == loop.id)
  }

  @Test("only one Loop is Focused at a time")
  func onlyOne() throws {
    let (core, _) = try makeCore()
    let first = try core.capture(title: "First")
    let second = try core.capture(title: "Second")

    try core.focus(first.id)
    try core.focus(second.id)

    #expect(try core.focusedLoop()?.id == second.id)
  }

  @Test("Unfocus leaves no Loop Focused")
  func unfocus() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Pricing proposal")
    try core.focus(loop.id)

    try core.unfocus()

    #expect(try core.focusedLoop() == nil)
  }

  @Test("Focusing an unknown Loop fails and changes nothing")
  func unknownLoop() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Real")
    try core.focus(loop.id)

    #expect(throws: CoreError.loopNotFound) { try core.focus(UUID()) }
    #expect(try core.focusedLoop()?.id == loop.id)
  }

  @Test("Focus survives reopening the database")
  func persists() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("unfocused.sqlite")
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let time = TestTime()
    let core = try Core(database: .open(at: url), time: time)
    let loop = try core.capture(title: "Keep going")
    try core.focus(loop.id)

    let reopened = try Core(database: .open(at: url), time: time)

    #expect(try reopened.focusedLoop()?.id == loop.id)
  }

  @Test("each Focus is recorded with its start and end")
  func sessions() throws {
    let (core, time) = try makeCore()
    let first = try core.capture(title: "First")
    let second = try core.capture(title: "Second")
    let start = time.now

    try core.focus(first.id)
    time.advance(by: .minutes(25))
    try core.focus(second.id)
    time.advance(by: .minutes(10))
    try core.unfocus()

    let firstSessions = try core.focusSessions(for: first.id)
    #expect(firstSessions.map(\.start) == [start])
    #expect(firstSessions.map(\.end) == [start.addingTimeInterval(.minutes(25))])
    #expect(try core.focusSessions(for: second.id).map(\.duration) == [.minutes(10)])
  }

  @Test("Focusing the already Focused Loop doesn't start a new Focus")
  func refocusIsNoOp() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Same")
    try core.focus(loop.id)
    time.advance(by: .minutes(5))

    try core.focus(loop.id)

    #expect(try core.focusSessions(for: loop.id).count == 1)
  }
}

@Suite("Where I left off")
struct WhereILeftOffTests {
  @Test("is stored on the Loop, trimmed")
  func stores() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Contract draft")

    try core.setWhereILeftOff(loop.id, to: "  Section 4 needs Anna's numbers \n")

    #expect(try core.loop(loop.id)?.whereILeftOff == "Section 4 needs Anna's numbers")
  }

  @Test("an empty note keeps the previous one")
  func emptyKeepsPrevious() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Contract draft")
    try core.setWhereILeftOff(loop.id, to: "Section 4")

    try core.setWhereILeftOff(loop.id, to: "   ")

    #expect(try core.loop(loop.id)?.whereILeftOff == "Section 4")
  }

  @Test("is shown with the Focused Loop")
  func shownWhenFocused() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Contract draft")
    try core.setWhereILeftOff(loop.id, to: "Section 4")

    try core.focus(loop.id)

    #expect(try core.focusedLoop()?.whereILeftOff == "Section 4")
  }

  @Test("an unknown Loop fails")
  func unknown() throws {
    let (core, _) = try makeCore()
    #expect(throws: CoreError.loopNotFound) { try core.setWhereILeftOff(UUID(), to: "x") }
  }
}
