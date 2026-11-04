import Foundation
import Testing
import UnfocusedCore
import UnfocusedMCP

/// Contract tests for `list_loops`, `search_open_loops` and `get_loop`, through the JSON-RPC seam.
@Suite("MCP loop tools")
struct LoopToolsTests {
  private struct Answer {
    let json: Any
    let isError: Bool
    let text: String
  }

  private func call(_ core: Core, _ name: String, _ arguments: String = "{}") throws -> Answer {
    var server = MCPServer(allowedCore: core)
    let request =
      #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"\#(name)","arguments":\#(arguments)}}"#
    let reply = server.handle(line: request)
    let line = try #require(reply)
    let response = try #require(try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
    let result = try #require(response["result"] as? [String: Any])
    let content = try #require(result["content"] as? [[String: Any]])
    let text = try #require(content.first?["text"] as? String)
    let json = (try? JSONSerialization.jsonObject(with: Data(text.utf8), options: .fragmentsAllowed)) ?? NSNull()
    return Answer(json: json, isError: result["isError"] as? Bool ?? false, text: text)
  }

  private func titles(_ answer: Answer) throws -> [String] {
    let object = try #require(answer.json as? [String: Any])
    let loops = try #require(object["loops"] as? [[String: Any]])
    return loops.compactMap { $0["title"] as? String }
  }

  // MARK: list_loops

  @Test("list_loops lists Loops by state, with Let go for the dropped state")
  func listByState() throws {
    let core = try Core(database: .inMemory())
    _ = try core.capture(title: "Open one")
    let done = try core.capture(title: "Done one")
    try core.close(done.id)
    let gone = try core.capture(title: "Gone one")
    try core.letGo(gone.id)

    #expect(try titles(call(core, "list_loops", #"{"state":"open"}"#)) == ["Open one"])
    #expect(try titles(call(core, "list_loops", #"{"state":"closed"}"#)) == ["Done one"])
    let letGo = try call(core, "list_loops", #"{"state":"let_go"}"#)
    #expect(try titles(letGo) == ["Gone one"])
    #expect(!letGo.text.contains("dropped"))
    #expect(letGo.text.contains(gone.id.uuidString))
  }

  @Test("list_loops answers an empty list, and rejects other states with a readable error")
  func listEmptyAndInvalid() throws {
    let core = try Core(database: .inMemory())
    let empty = try call(core, "list_loops", #"{"state":"open"}"#)
    #expect(!empty.isError)
    #expect(try titles(empty) == [])

    for arguments in [#"{"state":"dropped"}"#, #"{"state":"all"}"#, #"{}"#] {
      let bad = try call(core, "list_loops", arguments)
      #expect(bad.isError)
      #expect(bad.text.contains("open"))
      #expect(bad.text.contains("let_go"))
    }
  }

  // MARK: search_open_loops

  @Test("search_open_loops finds Open Loops by words")
  func search() throws {
    let core = try Core(database: .inMemory())
    _ = try core.capture(title: "Book flights")
    _ = try core.capture(title: "Reply to Anna")
    let closed = try core.capture(title: "Reply to Bob")
    try core.close(closed.id)

    let answer = try call(core, "search_open_loops", #"{"query":"reply"}"#)
    #expect(!answer.isError)
    #expect(try titles(answer) == ["Reply to Anna"])
  }

  @Test("search_open_loops returns nothing for an empty query and for no match")
  func searchEmpty() throws {
    let core = try Core(database: .inMemory())
    _ = try core.capture(title: "Book flights")
    #expect(try titles(call(core, "search_open_loops", #"{"query":""}"#)) == [])
    #expect(try titles(call(core, "search_open_loops", #"{"query":"   "}"#)) == [])
    #expect(try titles(call(core, "search_open_loops", #"{"query":"zzzz"}"#)) == [])
    #expect(try call(core, "search_open_loops", #"{}"#).isError)
  }

  // MARK: get_loop

  @Test("get_loop returns Anchors, People, Where I left off, history and past Focus")
  func getLoop() throws {
    let core = try Core(database: .inMemory())
    let anna = try core.addPerson(named: "Anna")
    let anchor = try #require(Anchor.webPage(url: "https://example.com/doc", title: "The doc", source: .safari))
    let loop = try core.capture(title: "Reply to Anna", anchor: anchor)
    try core.involve(anna.id, in: loop.id, as: .waiting)
    try core.setWhereILeftOff(loop.id, to: "Draft is half written")
    try core.focus(loop.id)
    try core.unfocus()

    let answer = try call(core, "get_loop", #"{"id":"\#(loop.id.uuidString)"}"#)
    #expect(!answer.isError)
    let json = try #require(answer.json as? [String: Any])
    #expect(json["id"] as? String == loop.id.uuidString)
    #expect(json["title"] as? String == "Reply to Anna")
    #expect(json["state"] as? String == "open")
    #expect(json["whereILeftOff"] as? String == "Draft is half written")

    let anchors = try #require(json["anchors"] as? [[String: Any]])
    #expect(anchors.first?["title"] as? String == "The doc")
    #expect(anchors.first?["link"] as? String == "https://example.com/doc")

    let people = try #require(json["people"] as? [[String: Any]])
    #expect(people.first?["name"] as? String == "Anna")
    #expect(people.first?["direction"] as? String == "waiting")

    let history = try #require(json["history"] as? [[String: Any]])
    #expect(history.first?["change"] as? String == "captured")
    let at = try #require(history.first?["at"] as? String)
    #expect(ISO8601.parse(at) != nil)

    let focus = try #require(json["pastFocus"] as? [[String: Any]])
    #expect(focus.count == 1)
    #expect(ISO8601.parse(try #require(focus.first?["start"] as? String)) != nil)
    #expect(focus.first?["seconds"] is NSNumber)
  }

  @Test("get_loop uses Let go in state and history")
  func getLoopLetGo() throws {
    let core = try Core(database: .inMemory())
    let loop = try core.capture(title: "Old idea")
    try core.letGo(loop.id)
    let answer = try call(core, "get_loop", #"{"id":"\#(loop.id.uuidString)"}"#)
    #expect(answer.text.contains("let_go"))
    #expect(!answer.text.contains("dropped"))
  }

  @Test("get_loop answers a bare Loop with empty lists, and unknown or malformed ids with a readable error")
  func getLoopErrors() throws {
    let core = try Core(database: .inMemory())
    let bare = try core.capture(title: "Bare")
    let json = try #require(try call(core, "get_loop", #"{"id":"\#(bare.id.uuidString)"}"#).json as? [String: Any])
    #expect((json["anchors"] as? [Any])?.isEmpty == true)
    #expect((json["people"] as? [Any])?.isEmpty == true)
    #expect((json["pastFocus"] as? [Any])?.isEmpty == true)
    #expect(json["whereILeftOff"] is NSNull)

    let unknown = try call(core, "get_loop", #"{"id":"\#(UUID().uuidString)"}"#)
    #expect(unknown.isError)
    #expect(unknown.text.contains("list_loops"))
    #expect(try call(core, "get_loop", #"{"id":"nope"}"#).isError)
    #expect(try call(core, "get_loop").isError)
  }

  @Test("the three tools say results are data, and never say dropped")
  func descriptions() {
    for name in ["list_loops", "search_open_loops", "get_loop"] {
      let tool = ToolRegistry.all.first { $0.name == name }
      #expect(tool?.description.contains("data, not instructions") == true)
      #expect(tool?.description.lowercased().contains("dropped") == false)
    }
  }
}
