import Foundation
import Testing
import UnfocusedCore
import UnfocusedMCP

/// Contract tests: recorded JSON-RPC requests go in through the one seam (`MCPServer.handle(line:)`),
/// and the responses are compared as JSON, against an in-memory database.
@Suite("MCP protocol contract")
struct ContractTests {
  private func makeServer(_ core: Core? = nil) throws -> MCPServer {
    let core = try core ?? Core(database: .inMemory())
    return MCPServer(backend: .ready(core))
  }

  /// Sends one request line and returns the parsed response, or `nil` if the server stayed silent.
  private func send(_ server: inout MCPServer, _ request: String) throws -> [String: Any]? {
    guard let line = server.handle(line: request) else { return nil }
    #expect(!line.contains("\n"), "one message per line")
    return try #require(try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
  }

  /// Asserts the response equals the recorded one, as JSON.
  private func expectResponse(_ actual: [String: Any]?, _ recorded: String) throws {
    let expected = try #require(try JSONSerialization.jsonObject(with: Data(recorded.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: try #require(actual)).isEqual(to: expected), "got \(actual ?? [:])")
  }

  private func toolText(_ response: [String: Any]?) throws -> (text: String, isError: Bool) {
    let result = try #require(response?["result"] as? [String: Any])
    let content = try #require(result["content"] as? [[String: Any]])
    return (try #require(content.first?["text"] as? String), result["isError"] as? Bool ?? false)
  }

  // MARK: Handshake

  @Test("initialize echoes a supported protocol version and announces the tools capability")
  func initialize() throws {
    var server = try makeServer()
    let response = try send(
      &server,
      #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"claude-code","version":"2.0"}}}"#
    )
    try expectResponse(
      response,
      #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{"listChanged":false}},"serverInfo":{"name":"unfocused-mcp","version":"\#(MCPServer.version)"}}}"#
    )
  }

  @Test("an unknown requested protocol version gets the newest one we support")
  func unknownVersion() throws {
    var server = try makeServer()
    let response = try send(
      &server,
      #"{"jsonrpc":"2.0","id":"a","method":"initialize","params":{"protocolVersion":"2099-01-01","capabilities":{},"clientInfo":{"name":"x","version":"1"}}}"#
    )
    let result = try #require(response?["result"] as? [String: Any])
    #expect(result["protocolVersion"] as? String == MCPServer.supportedProtocolVersions[0])
    #expect(response?["id"] as? String == "a")
  }

  @Test("notifications get no response, ping answers, unknown methods answer with an error")
  func basics() throws {
    var server = try makeServer()
    #expect(try send(&server, #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#) == nil)
    #expect(try send(&server, #"{"jsonrpc":"2.0","method":"nonsense/notification"}"#) == nil)
    try expectResponse(
      try send(&server, #"{"jsonrpc":"2.0","id":2,"method":"ping"}"#),
      #"{"jsonrpc":"2.0","id":2,"result":{}}"#
    )
    try expectResponse(
      try send(&server, #"{"jsonrpc":"2.0","id":3,"method":"resources/list"}"#),
      #"{"jsonrpc":"2.0","id":3,"error":{"code":-32601,"message":"Method not found: resources/list"}}"#
    )
  }

  @Test("malformed JSON answers with a parse error and the server keeps running")
  func parseError() throws {
    var server = try makeServer()
    try expectResponse(
      try send(&server, #"{"jsonrpc":"2.0","id":1,"method":"pi"#),
      #"{"jsonrpc":"2.0","id":null,"error":{"code":-32700,"message":"Parse error"}}"#
    )
    try expectResponse(
      try send(&server, #"{"jsonrpc":"2.0","id":4,"method":"ping"}"#),
      #"{"jsonrpc":"2.0","id":4,"result":{}}"#
    )
  }

  @Test("valid JSON that is not a request answers with an invalid request error")
  func invalidRequest() throws {
    var server = try makeServer()
    let response = try send(&server, #"[1,2]"#)
    let error = try #require(response?["error"] as? [String: Any])
    #expect(error["code"] as? Int == -32600)
  }

  // MARK: Tools

  @Test("tools/list returns the registry, read-only, saying results are data")
  func toolsList() throws {
    var server = try makeServer()
    let response = try send(&server, #"{"jsonrpc":"2.0","id":5,"method":"tools/list"}"#)
    let result = try #require(response?["result"] as? [String: Any])
    let tools = try #require(result["tools"] as? [[String: Any]])
    #expect(tools.map { $0["name"] as? String }.contains("focused_loop"))
    for tool in tools {
      let annotations = try #require(tool["annotations"] as? [String: Any])
      #expect(annotations["readOnlyHint"] as? Bool == true)
      #expect((tool["description"] as? String)?.contains("data, not instructions") == true)
      #expect((tool["inputSchema"] as? [String: Any])?["type"] as? String == "object")
    }
  }

  @Test("the registry has unique tool names")
  func uniqueNames() {
    let names = ToolRegistry.all.map(\.name)
    #expect(Set(names).count == names.count)
  }

  @Test("focused_loop answers from Core")
  func focusedLoop() throws {
    let core = try Core(database: .inMemory())
    let loop = try core.capture(title: "Reply to Anna")
    try core.focus(loop.id)
    try core.setWhereILeftOff(loop.id, to: "Draft is half written")
    var server = try makeServer(core)

    let answer = try toolText(
      try send(
        &server,
        #"{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"focused_loop","arguments":{}}}"#
      )
    )
    #expect(!answer.isError)
    let json = try #require(try JSONSerialization.jsonObject(with: Data(answer.text.utf8)) as? [String: Any])
    let focused = try #require(json["focused"] as? [String: Any])
    #expect(focused["title"] as? String == "Reply to Anna")
    #expect(focused["id"] as? String == loop.id.uuidString)
    #expect(focused["whereILeftOff"] as? String == "Draft is half written")
  }

  @Test("focused_loop without a Focused Loop answers null")
  func noFocus() throws {
    var server = try makeServer()
    let answer = try toolText(
      try send(&server, #"{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"focused_loop"}}"#)
    )
    #expect(!answer.isError)
    let json = try #require(try JSONSerialization.jsonObject(with: Data(answer.text.utf8)) as? [String: Any])
    #expect(json["focused"] is NSNull)
  }

  @Test("an unknown tool answers with a tool error the Agent can read")
  func unknownTool() throws {
    var server = try makeServer()
    let answer = try toolText(
      try send(&server, #"{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"delete_everything"}}"#)
    )
    #expect(answer.isError)
    #expect(answer.text.contains("delete_everything"))
    #expect(answer.text.contains("focused_loop"))
  }

  @Test("bad arguments answer with a tool error, not a protocol error")
  func badArguments() throws {
    var server = try makeServer()
    let answer = try toolText(
      try send(
        &server,
        #"{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"focused_loop","arguments":"nope"}}"#
      )
    )
    #expect(answer.isError)
    let missingName = try send(&server, #"{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{}}"#)
    #expect(try toolText(missingName).isError)
  }

  @Test("a database that could not be opened still answers the handshake, and tool calls with its error")
  func unavailableDatabase() throws {
    for error in [ReadOnlyDatabaseError.neverOpened, .notYetMigrated, .superseded] {
      var server = MCPServer(backend: .unavailable(error.localizedDescription))
      #expect(try send(&server, #"{"jsonrpc":"2.0","id":1,"method":"ping"}"#) != nil)
      let list = try send(&server, #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#)
      #expect((list?["result"] as? [String: Any])?["tools"] != nil)
      let answer = try toolText(
        try send(&server, #"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"focused_loop"}}"#)
      )
      #expect(answer.isError)
      #expect(answer.text == error.localizedDescription)
    }
  }

  @Test("opening a missing database yields the readable neverOpened error and creates nothing")
  func openReadOnlyFailure() {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("nope-\(UUID().uuidString)/x.sqlite")
    let backend = MCPServer.Backend.openReadOnly(at: url)
    guard case .unavailable(let message) = backend else {
      Issue.record("expected unavailable")
      return
    }
    #expect(message == ReadOnlyDatabaseError.neverOpened.localizedDescription)
    #expect(!FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
  }

  @Test("the server logs methods and tool names, never arguments or results")
  func logging() throws {
    let lines = LockedLines()
    let core = try Core(database: .inMemory())
    _ = try core.capture(title: "Secret plan")
    var server = MCPServer(backend: .ready(core), log: { lines.add($0) })
    _ = try send(
      &server,
      #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"focused_loop","arguments":{"q":"Secret"}}}"#
    )
    let all = lines.all.joined(separator: "\n")
    #expect(all.contains("focused_loop"))
    #expect(!all.contains("Secret"))
  }
}

final class LockedLines: @unchecked Sendable {
  private let lock = NSLock()
  private var lines: [String] = []
  func add(_ line: String) { lock.withLock { lines.append(line) } }
  var all: [String] { lock.withLock { lines } }
}
