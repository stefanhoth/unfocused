public import Foundation
public import UnfocusedCore

/// The MCP protocol layer (ADR 0007): a minimal JSON-RPC 2.0 server for tools over newline-delimited
/// messages. Everything goes through ``handle(line:)``, the one seam; replacing this type with the
/// official Swift SDK later changes nothing else.
public struct MCPServer {
  public static let version = "1"
  /// Newest first. An unknown requested version is answered with the first one.
  public static let supportedProtocolVersions = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]

  /// What the tools read from.
  public enum Backend {
    case ready(Core)
    /// The database could not be opened; the message says what the user can do. The server still
    /// answers the handshake and lists tools, and answers every tool call with this message.
    case unavailable(String)

    /// Opens the database read-only (never creates, migrates or writes).
    public static func openReadOnly(at url: URL) -> Backend {
      do {
        return .ready(Core(database: try UnfocusedDatabase.openReadOnly(at: url)))
      } catch {
        return .unavailable(error.localizedDescription)
      }
    }
  }

  private let backend: Backend
  private let tools: [any MCPTool]
  private let log: @Sendable (String) -> Void
  /// The Agent's name from `initialize`'s `clientInfo`, for the call log.
  public private(set) var clientName: String?

  /// - Parameter log: receives one line per request: method and tool name, never arguments or results.
  public init(
    backend: Backend,
    tools: [any MCPTool] = ToolRegistry.all,
    log: @escaping @Sendable (String) -> Void = { _ in }
  ) {
    self.backend = backend
    self.tools = tools
    self.log = log
  }

  /// Handles one incoming message line. Returns the response line, or `nil` for notifications.
  public mutating func handle(line: String) -> String? {
    guard let message = JSONValue(parsing: line) else {
      return Self.error(id: .null, code: -32700, message: "Parse error")
    }
    guard let request = message.object, let method = request["method"]?.string else {
      return Self.error(id: .null, code: -32600, message: "Invalid Request")
    }
    guard let id = request["id"] else {
      log("notification \(method)")
      return nil
    }
    let params = request["params"]?.object ?? [:]
    switch method {
    case "initialize":
      log("initialize")
      return Self.result(id: id, initialize(params))
    case "ping":
      log("ping")
      return Self.result(id: id, [:])
    case "tools/list":
      log("tools/list")
      return Self.result(id: id, ["tools": .array(tools.map(Self.describe))])
    case "tools/call":
      return Self.result(id: id, call(params))
    default:
      log("unknown method \(method)")
      return Self.error(id: id, code: -32601, message: "Method not found: \(method)")
    }
  }

  // MARK: Methods

  private mutating func initialize(_ params: [String: JSONValue]) -> JSONValue {
    clientName = params["clientInfo"]?.object?["name"]?.string
    let requested = params["protocolVersion"]?.string
    let version = requested.flatMap { Self.supportedProtocolVersions.contains($0) ? $0 : nil }
    return [
      "protocolVersion": .string(version ?? Self.supportedProtocolVersions[0]),
      "capabilities": ["tools": ["listChanged": false]],
      "serverInfo": ["name": "unfocused-mcp", "version": .string(Self.version)],
    ]
  }

  private func call(_ params: [String: JSONValue]) -> JSONValue {
    guard let name = params["name"]?.string else {
      return Self.toolResult("Missing tool name. Call tools/list to see the tools.", isError: true)
    }
    log("tools/call \(name)")
    let tool = tools.first(where: { $0.name == name })
    // The consent gate (ADR 0007): checked on every call, before anything else is answered, so a
    // refused call reveals no data, not even which tools exist beyond the listed ones.
    if case .ready(let core) = backend {
      let decision: AgentAccessDecision
      do {
        decision = try core.agentAccessDecision(for: tool?.requiredAccess ?? .loops)
      } catch {
        // Fail closed: if the switch can't be read, nothing is shared.
        return Self.toolResult(Self.refusal(.loopsOff), isError: true)
      }
      if decision != .allowed {
        log("refused \(name): \(decision)")
        return Self.toolResult(Self.refusal(decision), isError: true)
      }
    }
    guard let tool else {
      let known = tools.map(\.name).joined(separator: ", ")
      return Self.toolResult("Unknown tool '\(name)'. Available tools: \(known).", isError: true)
    }
    let arguments: ToolArguments
    switch params["arguments"] {
    case nil, .null?: arguments = ToolArguments()
    case .object(let values)?: arguments = ToolArguments(values)
    default: return Self.toolResult("Arguments must be a JSON object.", isError: true)
    }
    switch backend {
    case .unavailable(let message):
      return Self.toolResult(message, isError: true)
    case .ready(let core):
      do {
        return Self.toolResult(try tool.call(arguments: arguments, core: core), isError: false)
      } catch {
        return Self.toolResult(error.localizedDescription, isError: true)
      }
    }
  }

  /// What the Agent tells the user when access is off.
  static func refusal(_ decision: AgentAccessDecision) -> String {
    switch decision {
    case .allowed, .loopsOff:
      return
        "Agent access is off, so unfocused shares nothing yet. To allow it, tell the user to open unfocused, go to Settings, and turn on \"Let Agents read my Loops\" under Agent access. It applies to the next request; no restart needed."
    case .activityOff:
      return
        "Agent access to Activity is off. To allow it, tell the user to open unfocused, go to Settings, and turn on \"Let Agents read my Activity\" under Agent access. It applies to the next request; no restart needed."
    }
  }

  // MARK: Encoding

  private static func describe(_ tool: any MCPTool) -> JSONValue {
    [
      "name": .string(tool.name),
      "description": .string(tool.description),
      "inputSchema": tool.inputSchema,
      "annotations": ["readOnlyHint": true],
    ]
  }

  private static func toolResult(_ text: String, isError: Bool) -> JSONValue {
    ["content": [["type": "text", "text": .string(text)]], "isError": .bool(isError)]
  }

  private static func result(id: JSONValue, _ result: JSONValue) -> String {
    JSONValue.object(["jsonrpc": "2.0", "id": id, "result": result]).compact()
  }

  private static func error(id: JSONValue, code: Int, message: String) -> String {
    let error: JSONValue = ["code": .number(Double(code)), "message": .string(message)]
    return JSONValue.object(["jsonrpc": "2.0", "id": id, "error": error]).compact()
  }
}
