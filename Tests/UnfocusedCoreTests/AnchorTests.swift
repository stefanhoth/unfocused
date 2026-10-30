import Foundation
import Testing
import UnfocusedCore

@Suite("Anchors from web pages")
struct WebAnchorTests {
  private func identifier(_ raw: String) throws -> String {
    try #require(Anchor.webPage(url: raw, title: "t", source: .safari)).identifier
  }

  @Test("the identifier ignores letter case in the host, fragments and a trailing slash")
  func normalizes() throws {
    #expect(try identifier("https://Docs.Example.com/Guide/#intro") == identifier("https://docs.example.com/Guide"))
  }

  @Test("tracking parameters don't change the identifier, other parameters do")
  func trackingParameters() throws {
    let plain = try identifier("https://example.com/post?id=7")
    #expect(try identifier("https://example.com/post?utm_source=x&id=7&fbclid=abc") == plain)
    #expect(try identifier("https://example.com/post?id=8") != plain)
  }

  @Test("http and https are the same page")
  func scheme() throws {
    #expect(try identifier("http://example.com/a") == identifier("https://example.com/a"))
  }

  @Test("keeps the original URL to reopen the page")
  func keepsLink() throws {
    let anchor = try #require(Anchor.webPage(url: "https://example.com/a#b", title: "A page", source: .chrome))
    #expect(anchor.link == "https://example.com/a#b")
    #expect(anchor.title == "A page")
    #expect(anchor.source == .chrome)
  }

  @Test("pages that can't be reopened aren't Anchors")
  func rejects() {
    #expect(Anchor.webPage(url: "", title: "x", source: .safari) == nil)
    #expect(Anchor.webPage(url: "about:blank", title: "x", source: .safari) == nil)
    #expect(Anchor.webPage(url: "favorites://", title: "x", source: .safari) == nil)
  }
}

@Suite("Fallback Anchors")
struct AppAnchorTests {
  @Test("an app and its window title make an Anchor that reopens the app")
  func appWindow() {
    let anchor = Anchor.appWindow(bundleID: "com.apple.Notes", appName: "Notes", windowTitle: "Groceries")
    #expect(anchor.source == .app("com.apple.Notes"))
    #expect(anchor.title == "Notes: Groceries")
    #expect(anchor.link == "com.apple.Notes")
  }

  @Test("without a window title the app name is the title")
  func appOnly() {
    let anchor = Anchor.appWindow(bundleID: "com.apple.Notes", appName: "Notes", windowTitle: nil)
    #expect(anchor.title == "Notes")
    #expect(
      anchor.identifier != Anchor.appWindow(bundleID: "com.apple.Notes", appName: "Notes", windowTitle: "x").identifier
    )
  }
}

@Suite("Capturing with an Anchor")
struct CaptureWithAnchorTests {
  @Test("the Anchor is stored with the new Loop")
  func storesAnchor() throws {
    let (core, _) = try makeCore()
    let anchor = try #require(Anchor.webPage(url: "https://example.com/a", title: "A", source: .safari))

    let loop = try core.capture(title: "Read A", anchor: anchor)

    #expect(try core.anchors(of: loop.id) == [anchor])
  }

  @Test("an empty title falls back to the Anchor's title")
  func titleFromAnchor() throws {
    let (core, _) = try makeCore()
    let anchor = try #require(Anchor.webPage(url: "https://example.com/a", title: "Quarterly report", source: .safari))

    let loop = try core.capture(title: " ", anchor: anchor)

    #expect(loop.title == "Quarterly report")
  }

  @Test("a Loop captured without context has no Anchors")
  func noAnchor() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Just an idea")
    #expect(try core.anchors(of: loop.id).isEmpty)
  }
}
