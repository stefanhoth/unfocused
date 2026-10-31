import Foundation
import Testing
import UnfocusedCore

private func page(_ path: String) -> Anchor {
  guard let anchor = Anchor.webPage(url: "https://example.com/\(path)", title: path, source: .safari) else {
    preconditionFailure("test URL must be valid")
  }
  return anchor
}

private func activeDays(_ count: Int, _ core: Core, _ time: TestTime) throws {
  for _ in 0..<count {
    time.advance(by: .days(1))
    try core.recordActivity(page("elsewhere"))
  }
}

@Suite("Tie-off")
struct TieOffTests {
  @Test("a Tie-off walks the Loose Ends one at a time, most aged first")
  func order() throws {
    let (core, time) = try makeCore()
    let older = try core.capture(title: "Older")
    try activeDays(1, core, time)
    let newer = try core.capture(title: "Newer")
    try activeDays(3, core, time)
    _ = try core.capture(title: "Fresh")

    var tieOff = try core.startTieOff()
    #expect(tieOff.total == 2)
    #expect(tieOff.current?.loop.id == older.id)
    tieOff.next()
    #expect(tieOff.current?.loop.id == newer.id)
    tieOff.next()
    #expect(tieOff.current == nil)
    #expect(tieOff.isFinished)
  }

  @Test("Not now moves on without counting as Engagement, so the Loop comes up next time")
  func notNow() throws {
    let (core, time) = try makeCore()
    let loop = try core.capture(title: "Spec")
    try activeDays(3, core, time)

    var tieOff = try core.startTieOff()
    tieOff.notNow()
    #expect(tieOff.isFinished)
    #expect(tieOff.setAside.map(\.loop.id) == [loop.id])

    #expect(try core.lastEngagement(of: loop.id) == nil)
    #expect(try core.startTieOff().current?.loop.id == loop.id)
  }

  @Test("Loops resolved during a Tie-off don't come up next time")
  func resolved() throws {
    let (core, time) = try makeCore()
    let closeMe = try core.capture(title: "Close me")
    let dropMe = try core.capture(title: "Drop me")
    let focusMe = try core.capture(title: "Focus me")
    try activeDays(3, core, time)

    var tieOff = try core.startTieOff()
    try core.close(closeMe.id)
    tieOff.next()
    try core.drop(dropMe.id)
    tieOff.next()
    try core.focus(focusMe.id)
    tieOff.next()
    #expect(tieOff.isFinished)

    #expect(try core.startTieOff().total == 0)
  }

  @Test("with no Loose Ends, a Tie-off is finished right away")
  func empty() throws {
    let (core, _) = try makeCore()
    _ = try core.capture(title: "Fresh")
    #expect(try core.startTieOff().isFinished)
  }
}
