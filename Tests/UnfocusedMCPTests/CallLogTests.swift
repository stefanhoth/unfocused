import Foundation
import Testing
import UnfocusedCore
import UnfocusedMCP

/// Every `tools/call` is recorded with time, Agent name and tool, answered or refused, and never with
/// arguments or results (ADR 0007).
@Suite("MCP call log")
struct CallLogTests {
  private final class Sink: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [AgentCall] = []
    private var lines: [String] = []
    var calls: [AgentCall] { lock.withLock { items } }
    var logged: [String] { lock.withLock { lines } }
    func add(_ call: AgentCall) { lock.withLock { items.append(call) } }
    func log(_ line: String) { lock.withLock { lines.append(line) } }
  }

  private let initialize =
    #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","clientInfo":{"name":"Claude Code","version":"1"}}}"#
  private let moment = Date(timeIntervalSince1970: 1_793_800_000)

  private func call(_ name: String, _ arguments: String = "{}") -> String {
    #"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"\#(name)","arguments":\#(arguments)}}"#
  }

  private func makeServer(_ core: Core, allowed: Bool, sink: Sink) -> MCPServer {
    if allowed { try? core.setAgentAccess(.loops, allowed: true) }
    let moment = moment
    return MCPServer(
      backend: .ready(core),
      log: { sink.log($0) },
      onCall: { sink.add($0) },
      now: { moment }
    )
  }

  @Test("an answered call is recorded with the Agent's name and the tool")
  func answered() throws {
    let sink = Sink()
    var server = makeServer(try Core(database: .inMemory()), allowed: true, sink: sink)
    _ = server.handle(line: initialize)
    _ = server.handle(line: call("focused_loop"))
    let recorded = try #require(sink.calls.first)
    #expect(recorded.agent == "Claude Code")
    #expect(recorded.tool == "focused_loop")
    #expect(!recorded.refused)
    #expect(recorded.date == moment)
    #expect(sink.logged.contains("tools/call focused_loop by Claude Code"))
  }

  @Test("a refused call is recorded as refused")
  func refused() throws {
    let sink = Sink()
    var server = makeServer(try Core(database: .inMemory()), allowed: false, sink: sink)
    _ = server.handle(line: initialize)
    _ = server.handle(line: call("focused_loop"))
    #expect(sink.calls.first?.refused == true)
    #expect(sink.logged.contains("tools/call focused_loop by Claude Code (refused: access was off)"))
  }

  @Test("an Agent that sent no clientInfo is unknown, and the call still works")
  func unknownAgent() throws {
    let sink = Sink()
    var server = makeServer(try Core(database: .inMemory()), allowed: true, sink: sink)
    let reply = server.handle(line: call("focused_loop"))
    #expect(reply?.contains("\"isError\":false") == true)
    #expect(sink.calls.first?.agent == "unknown")
  }

  @Test("neither log nor record holds Loop titles, search text or arguments, even for unknown tool names")
  func noContent() throws {
    let sink = Sink()
    let core = try Core(database: .inMemory())
    let loop = try core.capture(title: "Secret plan")
    try core.focus(loop.id)
    var server = makeServer(core, allowed: true, sink: sink)
    _ = server.handle(line: initialize)
    _ = server.handle(line: call("search_open_loops", #"{"query":"Secret plan"}"#))
    _ = server.handle(line: call("Secret plan"))
    let everything = (sink.logged + sink.calls.map { "\($0)" }).joined(separator: "\n")
    #expect(!everything.contains("Secret"))
    #expect(sink.calls.last?.tool == "unknown")
  }
}
