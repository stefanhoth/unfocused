import Foundation
import Testing
import UnfocusedCore
import UnfocusedMCP

private final class Clock: TimeSource, @unchecked Sendable {
  private let lock = NSLock()
  private var current = Date(timeIntervalSince1970: 1_800_000_000)
  var now: Date { lock.withLock { current } }
  func advance(days: Int) { lock.withLock { current += TimeInterval(days * 86_400) } }
  func advance(minutes: Int) { lock.withLock { current += TimeInterval(minutes * 60) } }
}

/// Contract tests for `loose_ends` and `loops_involving`, through the server's one seam.
@Suite("MCP people tools")
struct PeopleToolsTests {
  private func makeCore() throws -> (Core, Clock) {
    let clock = Clock()
    return (try Core(database: .inMemory(), time: clock), clock)
  }

  private func call(
    _ core: Core,
    _ name: String,
    _ arguments: String = "{}"
  ) throws -> (json: [String: Any], isError: Bool) {
    var server = MCPServer(allowedCore: core)
    let request =
      #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"\#(name)","arguments":\#(arguments)}}"#
    let reply = server.handle(line: request)
    let line = try #require(reply)
    let parsed = try JSONSerialization.jsonObject(with: Data(line.utf8))
    let response = try #require(parsed as? [String: Any])
    let result = try #require(response["result"] as? [String: Any])
    let text = try #require((result["content"] as? [[String: Any]])?.first?["text"] as? String)
    let json = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any]
    return (json ?? ["text": text], result["isError"] as? Bool ?? false)
  }

  private func activeDay(_ core: Core, _ clock: Clock) throws {
    clock.advance(days: 1)
    let anchor = try #require(Anchor.webPage(url: "https://example.com/x", title: "x", source: .safari))
    try core.recordActivity(anchor)
    clock.advance(minutes: 1)
    try core.recordActivity(anchor)
  }

  // MARK: loose_ends

  @Test("loose_ends with nothing loose answers an empty list and the threshold")
  func noLooseEnds() throws {
    let (core, _) = try makeCore()
    _ = try core.capture(title: "Fresh")
    let answer = try call(core, "loose_ends")
    #expect(!answer.isError)
    #expect((answer.json["looseEnds"] as? [Any])?.isEmpty == true)
    #expect(answer.json["threshold"] as? Int == 3)
  }

  @Test("loose_ends lists Loose Ends in Core's order with active days and follow-up People")
  func looseEnds() throws {
    let (core, clock) = try makeCore()
    let older = try core.capture(title: "Older")
    let anna = try core.addPerson(named: "Anna")
    try core.involve(anna.id, in: older.id, as: .waiting)
    clock.advance(minutes: 5)
    let newer = try core.capture(title: "Newer")
    for _ in 0..<4 { try activeDay(core, clock) }

    let answer = try call(core, "loose_ends")
    let expected = try core.looseEnds()
    #expect(expected.count == 2)
    let items = try #require(answer.json["looseEnds"] as? [[String: Any]])
    #expect(items.map { ($0["loop"] as? [String: Any])?["id"] as? String } == expected.map(\.loop.id.uuidString))
    #expect(items.map { $0["activeDaysWithoutEngagement"] as? Int } == expected.map(\.activeDaysWithoutEngagement))
    #expect((items[0]["loop"] as? [String: Any])?["title"] as? String == "Older")
    #expect((items[1]["loop"] as? [String: Any])?["id"] as? String == newer.id.uuidString)
    let followUp = try #require(items[0]["followUp"] as? [[String: Any]])
    #expect(followUp.map { $0["name"] as? String } == ["Anna"])
    #expect((items[1]["followUp"] as? [Any])?.isEmpty == true)
  }

  @Test("loose_ends follows the configured threshold")
  func threshold() throws {
    let (core, clock) = try makeCore()
    _ = try core.capture(title: "Spec")
    try core.setLooseEndThreshold(1)
    try activeDay(core, clock)
    let answer = try call(core, "loose_ends")
    #expect(answer.json["threshold"] as? Int == 1)
    #expect((answer.json["looseEnds"] as? [Any])?.count == 1)
  }

  // MARK: loops_involving

  @Test("loops_involving finds a Person by partial, differently cased name, with direction")
  func involvingPartial() throws {
    let (core, _) = try makeCore()
    let reply = try core.capture(title: "Reply to Anna")
    let review = try core.capture(title: "Review draft")
    let done = try core.capture(title: "Old thing")
    let anna = try core.addPerson(named: "Anna Berger")
    try core.involve(anna.id, in: reply.id, as: .owed)
    try core.involve(anna.id, in: review.id, as: .waiting)
    try core.involve(anna.id, in: done.id, as: .owed)
    try core.close(done.id)

    let answer = try call(core, "loops_involving", #"{"person":"berg"}"#)
    #expect(!answer.isError)
    #expect((answer.json["person"] as? [String: Any])?["name"] as? String == "Anna Berger")
    let loops = try #require(answer.json["loops"] as? [[String: Any]])
    let byTitle = Dictionary(
      uniqueKeysWithValues: loops.map { ($0["title"] as? String ?? "", $0["direction"] as? String) }
    )
    #expect(byTitle == ["Reply to Anna": "owed", "Review draft": "waiting"])
  }

  @Test("an exact name wins over longer names that also match")
  func exactWins() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Ping")
    let anna = try core.addPerson(named: "Anna")
    _ = try core.addPerson(named: "Anna Berger", evenIfSimilar: true)
    try core.involve(anna.id, in: loop.id, as: .owed)
    let answer = try call(core, "loops_involving", #"{"person":"ANNA"}"#)
    #expect((answer.json["person"] as? [String: Any])?["name"] as? String == "Anna")
  }

  @Test("a name matching several People answers with the candidates, not a guess")
  func ambiguous() throws {
    let (core, _) = try makeCore()
    let loop = try core.capture(title: "Ping")
    let one = try core.addPerson(named: "Anna Berger")
    _ = try core.addPerson(named: "Anna Schmidt")
    try core.involve(one.id, in: loop.id, as: .owed)
    let answer = try call(core, "loops_involving", #"{"person":"anna"}"#)
    #expect(!answer.isError)
    #expect(answer.json["loops"] == nil)
    let candidates = try #require(answer.json["candidates"] as? [[String: Any]])
    #expect(Set(candidates.compactMap { $0["name"] as? String }) == ["Anna Berger", "Anna Schmidt"])
    #expect((answer.json["message"] as? String)?.contains("Which one") == true)
  }

  @Test("no match answers with a readable 'no Person called'")
  func noMatch() throws {
    let (core, _) = try makeCore()
    _ = try core.addPerson(named: "Anna")
    let answer = try call(core, "loops_involving", #"{"person":"Zed"}"#)
    #expect(!answer.isError)
    #expect((answer.json["message"] as? String) == "No Person called \"Zed\".")
  }

  @Test("a Person without Open Loops answers an empty list; a missing argument is a tool error")
  func emptyAndMissing() throws {
    let (core, _) = try makeCore()
    _ = try core.addPerson(named: "Anna")
    let empty = try call(core, "loops_involving", #"{"person":"Anna"}"#)
    #expect((empty.json["loops"] as? [Any])?.isEmpty == true)
    #expect(try call(core, "loops_involving").isError)
  }
}
