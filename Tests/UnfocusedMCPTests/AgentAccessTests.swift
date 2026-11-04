import Foundation
import Testing
import UnfocusedCore
import UnfocusedMCP

extension MCPServer {
  /// A server over `core` with Agent access for Loops already on, for tests about the tools.
  init(allowedCore core: Core, log: @escaping @Sendable (String) -> Void = { _ in }) {
    try? core.setAgentAccess(.loops, allowed: true)
    self.init(backend: .ready(core), log: log)
  }
}

/// Contract tests for the consent gate (ADR 0007): checked on every `tools/call`.
@Suite("MCP Agent access gate")
struct AgentAccessGateTests {
  private let list = #"{"jsonrpc":"2.0","id":1,"method":"tools/list"}"#
  private let focused =
    #"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"focused_loop","arguments":{}}}"#

  private func send(_ server: inout MCPServer, _ request: String) throws -> [String: Any] {
    let reply = server.handle(line: request)
    let line = try #require(reply)
    return try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
  }

  private func call(_ server: inout MCPServer) throws -> (text: String, isError: Bool) {
    let result = try #require(try send(&server, focused)["result"] as? [String: Any])
    let content = try #require(result["content"] as? [[String: Any]])
    return (try #require(content.first?["text"] as? String), result["isError"] as? Bool ?? false)
  }

  @Test("with access off, tools/list still works and every call says how to turn access on, with no data")
  func off() throws {
    let core = try Core(database: .inMemory())
    let loop = try core.capture(title: "Secret plan")
    try core.focus(loop.id)
    var server = MCPServer(backend: .ready(core))

    let tools = try #require((try send(&server, list)["result"] as? [String: Any])?["tools"] as? [[String: Any]])
    #expect(!tools.isEmpty)

    let answer = try call(&server)
    #expect(answer.isError)
    #expect(answer.text.contains("Settings"))
    #expect(answer.text.contains("Agent access"))
    #expect(!answer.text.contains("Secret plan"))
    #expect(!answer.text.contains(loop.id.uuidString))
  }

  @Test("an unknown tool name does not leak anything while access is off")
  func offUnknownTool() throws {
    var server = MCPServer(backend: .ready(try Core(database: .inMemory())))
    let request = #"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"nope"}}"#
    let result = try #require(try send(&server, request)["result"] as? [String: Any])
    #expect(result["isError"] as? Bool == true)
  }

  @Test("with access on, calls answer from Core")
  func on() throws {
    let core = try Core(database: .inMemory())
    try core.setAgentAccess(.loops, allowed: true)
    let loop = try core.capture(title: "Reply to Anna")
    try core.focus(loop.id)
    var server = MCPServer(backend: .ready(core))
    let answer = try call(&server)
    #expect(!answer.isError)
    #expect(answer.text.contains("Reply to Anna"))
  }

  @Test("switching mid-session applies to the next call without restarting")
  func switching() throws {
    let core = try Core(database: .inMemory())
    var server = MCPServer(backend: .ready(core))
    #expect(try call(&server).isError)
    try core.setAgentAccess(.loops, allowed: true)
    #expect(try !call(&server).isError)
    try core.setAgentAccess(.loops, allowed: false)
    #expect(try call(&server).isError)
  }

  @Test("through the read-only database, a switch the app flips applies to the next call")
  func readOnlySwitching() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("unfocused.sqlite")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let app = Core(database: try .open(at: url))
    var server = MCPServer(backend: .openReadOnly(at: url))

    #expect(try call(&server).isError)
    try app.setAgentAccess(.loops, allowed: true)
    #expect(try !call(&server).isError)
    try app.setAgentAccess(.loops, allowed: false)
    #expect(try call(&server).isError)
  }

  @Test("a setting that cannot be read refuses the call")
  func unreadable() throws {
    // An unavailable backend refuses with its own message (covered in ContractTests); here a gate
    // failure must never fall through to data. A closed database cannot be read.
    let database = try UnfocusedDatabase.inMemory()
    let core = Core(database: database)
    try core.setAgentAccess(.loops, allowed: true)
    var server = MCPServer(backend: .ready(core))
    try database.close()
    #expect(try call(&server).isError)
  }
}
