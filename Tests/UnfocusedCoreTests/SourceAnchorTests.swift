import Foundation
import Testing
import UnfocusedCore

/// Contract tests from recorded values: window titles, Finder paths and copied links.
@Suite("Notion, Todoist, Obsidian, Finder and Firefox Anchors")
struct SourceAnchorTests {
  @Test("a file is identified by its path and reopens in its app")
  func file() throws {
    let url = URL(fileURLWithPath: "/Users/ada/Documents/Budget 2027.numbers")
    let anchor = try #require(Anchor.file(url: url, bundleID: "com.apple.iWork.Numbers"))
    #expect(anchor.identifier == "file:/Users/ada/Documents/Budget 2027.numbers")
    #expect(anchor.link == "file:///Users/ada/Documents/Budget%202027.numbers")
    #expect(anchor.title == "Budget 2027.numbers")
    #expect(Anchor.file(url: try #require(URL(string: "https://example.com")), bundleID: "x") == nil)
  }

  @Test("the same file through a different path spelling is the same Anchor")
  func fileStandardized() throws {
    let a = try #require(Anchor.file(url: URL(fileURLWithPath: "/Users/ada/Docs/../Docs/a.pages"), bundleID: "x"))
    let b = try #require(Anchor.file(url: URL(fileURLWithPath: "/Users/ada/Docs/a.pages"), bundleID: "x"))
    #expect(a.identifier == b.identifier)
  }

  @Test(
    "Obsidian window titles give the note and vault",
    arguments: [
      (
        "Weekly plan - Work - Obsidian v1.6.7", "obsidian:Work/Weekly plan",
        "obsidian://open?vault=Work&file=Weekly%20plan"
      ),
      (
        "Q3 - draft - Notes - Obsidian v1.5.3", "obsidian:Notes/Q3 - draft",
        "obsidian://open?vault=Notes&file=Q3%20-%20draft"
      ),
    ]
  )
  func obsidian(title: String, identifier: String, link: String) throws {
    let anchor = try #require(Anchor.obsidianWindow(title: title))
    #expect(anchor.identifier == identifier)
    #expect(anchor.link == link)
  }

  @Test("Obsidian windows without a note give no Anchor")
  func obsidianOther() {
    #expect(Anchor.obsidianWindow(title: "Obsidian") == nil)
    #expect(Anchor.obsidianWindow(title: "Work - Obsidian v1.6.7") == nil)
  }

  @Test("Firefox window titles give the page, and private windows are flagged")
  func firefox() throws {
    let normal = try #require(Anchor.firefoxWindow(title: "Pricing — Mozilla Firefox"))
    #expect(normal.anchor.identifier == "firefox:Pricing")
    #expect(normal.anchor.source == .firefox)
    #expect(!normal.isPrivate)

    let hidden = try #require(Anchor.firefoxWindow(title: "Bank — Mozilla Firefox Private Browsing"))
    #expect(hidden.isPrivate)
    #expect(Anchor.firefoxWindow(title: "Mozilla Firefox") == nil)
  }

  @Test("Notion's window title is the page")
  func notion() throws {
    #expect(try #require(Anchor.notionWindow(title: "Q3 Hiring plan")).identifier == "notion-window:Q3 Hiring plan")
    #expect(Anchor.notionWindow(title: "Notion") == nil)
  }

  @Test("copied Notion and Todoist links are exact Anchors for their own app only")
  func copiedLinks() throws {
    let notion = try #require(
      Anchor.copiedLink("https://www.notion.so/acme/Q3-Hiring-plan-0123456789abcdef", for: "notion.id", title: "Q3")
    )
    #expect(notion.identifier == "web:www.notion.so/acme/Q3-Hiring-plan-0123456789abcdef")
    #expect(notion.source == .app("notion.id"))
    #expect(notion.title == "Q3")

    let task = try #require(
      Anchor.copiedLink("https://app.todoist.com/app/task/call-ada-6Xq9", for: "com.todoist.mac.Todoist")
    )
    #expect(task.identifier == "web:app.todoist.com/app/task/call-ada-6Xq9")

    #expect(Anchor.copiedLink("https://www.notion.so/x", for: "com.todoist.mac.Todoist") == nil)
    #expect(Anchor.copiedLink("https://example.com/x", for: "notion.id") == nil)
  }
}
