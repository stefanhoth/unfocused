import Foundation
import Testing
import UnfocusedCore

private func page(_ host: String, _ path: String) -> Anchor {
  guard let anchor = Anchor.webPage(url: "https://\(host)/\(path)", title: path, source: .safari) else {
    preconditionFailure("test URL must be valid")
  }
  return anchor
}

@Suite("Capture nudges")
struct CaptureNudgeTests {
  @Test("Loops with a similar title are related")
  func similarTitle() throws {
    let (core, _) = try makeCore()
    let budget = try core.capture(title: "Draft Q3 budget proposal")
    _ = try core.capture(title: "Book flights to Lisbon")

    let related = try core.relatedLoops(toCapture: "budget proposal for Q3", anchor: nil)
    #expect(related.map(\.loop.id) == [budget.id])
    #expect(related.first?.reasons == [.similarTitle])
  }

  @Test("Loops with a mentioned Person are related")
  func samePerson() throws {
    let (core, _) = try makeCore()
    let withAda = try core.capture(title: "Contract for @Ada")
    _ = try core.capture(title: "Something else")

    let related = try core.relatedLoops(toCapture: "Call @Ada about invoices", anchor: nil)
    #expect(related.map(\.loop.id) == [withAda.id])
    #expect(related.first?.reasons == [.samePerson("Ada")])
  }

  @Test("Loops whose Anchors live in the same place are related, but rank below title and People")
  func sameSource() throws {
    let (core, _) = try makeCore()
    let notion = try core.capture(title: "Roadmap", anchor: page("notion.so", "roadmap"))
    let titled = try core.capture(title: "Hiring plan draft")
    _ = try core.capture(title: "Groceries", anchor: page("example.com", "list"))

    let related = try core.relatedLoops(toCapture: "hiring plan", anchor: page("notion.so", "hiring"))
    #expect(related.map(\.loop.id) == [titled.id, notion.id])
    #expect(related.last?.reasons == [.sameSource])
  }

  @Test("more reasons rank higher; at most 3 are shown; only Open Loops")
  func ranking() throws {
    let (core, _) = try makeCore()
    let both = try core.capture(title: "Budget review with @Ada")
    let title = try core.capture(title: "Budget review slides")
    let person = try core.capture(title: "Lunch with @Ada")
    _ = try core.capture(title: "Budget review notes for later")
    let closed = try core.capture(title: "Budget review old")
    try core.close(closed.id)

    let related = try core.relatedLoops(toCapture: "Budget review @Ada", anchor: nil)
    #expect(related.map(\.loop.id) == [both.id, person.id, title.id])
    #expect(related.first?.reasons == [.samePerson("Ada"), .similarTitle])
  }

  @Test("short or common words alone don't make Loops related")
  func noiseWords() throws {
    let (core, _) = try makeCore()
    _ = try core.capture(title: "Write the intro for the talk")
    #expect(try core.relatedLoops(toCapture: "Read the paper for the team", anchor: nil).isEmpty)
  }

  @Test("an empty title has no related Loops by title")
  func emptyTitle() throws {
    let (core, _) = try makeCore()
    _ = try core.capture(title: "Anything")
    #expect(try core.relatedLoops(toCapture: "", anchor: nil).isEmpty)
  }

  @Test("the Loose End line appears once there are several Loose Ends")
  func looseEndLine() throws {
    let (core, time) = try makeCore()
    for index in 0..<3 { _ = try core.capture(title: "Old \(index)") }
    #expect(try core.looseEndsOlderThanNewIdea() == nil)

    for _ in 0..<3 {
      time.advance(by: .days(1))
      try core.recordActivity(page("example.com", "elsewhere"))
    }
    #expect(try core.looseEndsOlderThanNewIdea() == 3)
  }
}
