import Foundation
import Testing
import UnfocusedCore

private func page(_ path: String) -> Anchor {
  Anchor.webPage(url: "https://example.com/\(path)", title: path, source: .chrome)!
}

@Suite("One Loop per Anchor")
struct AnchorOwnershipTests {
  @Test("the Loop that already has an Anchor is found, even from a slightly different URL")
  func findsOwner() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Read a", anchor: page("a"))
    let sameSpot = try #require(
      Anchor.webPage(url: "https://EXAMPLE.com/a/?utm_source=mail", title: "a", source: .safari)
    )

    #expect(try core.loop(anchoredAt: sameSpot)?.id == loop.id)
    #expect(try core.loop(anchoredAt: page("b")) == nil)
  }

  @Test("an Open Loop wins over Closed ones with the same Anchor")
  func prefersOpen() throws {
    let (core, time) = try makeCore()
    let old = try core.capture(title: "Old", anchor: page("a"))
    try core.close(old.id)
    time.advance(by: 60)
    let current = try core.capture(title: "Current", anchor: page("a"))

    #expect(try core.loop(anchoredAt: page("a"))?.id == current.id)
  }

  @Test("a Closed Loop is still found, so it can be reopened")
  func findsClosed() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Done", anchor: page("a"))
    try core.close(loop.id)

    #expect(try core.loop(anchoredAt: page("a"))?.state == .closed)
  }

  @Test("Anchors can be added to a Loop later, without duplicates")
  func addAnchor() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Contract", anchor: page("email"))

    try core.addAnchor(page("doc"), to: loop.id)
    try core.addAnchor(page("doc"), to: loop.id)

    #expect(try core.anchors(of: loop.id).map(\.title) == ["email", "doc"])
    #expect(try core.loop(anchoredAt: page("doc"))?.id == loop.id)
  }

  @Test("Anchors can be removed from a Loop")
  func removeAnchor() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Contract", anchor: page("email"))

    try core.removeAnchor(page("email"), from: loop.id)

    #expect(try core.anchors(of: loop.id).isEmpty)
    #expect(try core.loop(anchoredAt: page("email")) == nil)
  }

  @Test("adding an Anchor to an unknown Loop fails")
  func unknownLoop() throws {
    let (core, _) = try makeCore()
    #expect(throws: CoreError.loopNotFound) { try core.addAnchor(page("a"), to: UUID()) }
  }
}
