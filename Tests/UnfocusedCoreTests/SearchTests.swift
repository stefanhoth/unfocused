import Testing
import UnfocusedCore

@Suite("Searching Open Loops")
struct SearchTests {
  private func titles(_ core: Core, _ query: String) throws -> [String] {
    try core.searchOpenLoops(query).map(\.title)
  }

  @Test("an empty query returns all Open Loops")
  func emptyQuery() throws {
    let (core, _) = try makeCore()
    _ = try core.capture(title: "One")
    _ = try core.capture(title: "Two")

    #expect(try core.searchOpenLoops("  ").count == 2)
  }

  @Test("matching ignores case and accents")
  func caseAndAccents() throws {
    let (core, _) = try makeCore()
    _ = try core.capture(title: "Résumé for Jörg")
    _ = try core.capture(title: "Unrelated")

    #expect(try titles(core, "resume JORG") == ["Résumé for Jörg"])
  }

  @Test("letters typed in order match across a word (fuzzy)")
  func subsequence() throws {
    let (core, _) = try makeCore()
    _ = try core.capture(title: "Quarterly budget review")
    _ = try core.capture(title: "Lunch")

    #expect(try titles(core, "qbr") == ["Quarterly budget review"])
  }

  @Test("every word of the query has to match")
  func allWords() throws {
    let (core, _) = try makeCore()
    _ = try core.capture(title: "Contract draft for Anna")
    _ = try core.capture(title: "Contract renewal")

    #expect(try titles(core, "contract anna") == ["Contract draft for Anna"])
  }

  @Test("whole-word and prefix matches rank above scattered letters")
  func ranking() throws {
    let (core, time) = try makeCore()
    _ = try core.capture(title: "Plan the offsite")
    time.advance(by: .minutes(1))
    _ = try core.capture(title: "Pricing proposal")
    time.advance(by: .minutes(1))
    _ = try core.capture(title: "Update pipeline alerts")

    #expect(try titles(core, "pri").first == "Pricing proposal")
  }

  @Test("equally good matches are ordered newest first")
  func tiesNewestFirst() throws {
    let (core, time) = try makeCore()
    _ = try core.capture(title: "Slack thread with Ben")
    time.advance(by: .minutes(1))
    _ = try core.capture(title: "Slack thread with Cleo")

    #expect(try titles(core, "slack") == ["Slack thread with Cleo", "Slack thread with Ben"])
  }
}
