import Foundation
import UnfocusedCore
import UnfocusedMCP

// Speaks MCP over stdio (ADR 0007). Protocol messages go to stdout only; logs go to the rotating
// log file and stderr. Needs no system permissions.

let logsDirectory = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent("Library/Logs/unfocused", isDirectory: true)
let stderrHandle = FileHandle.standardError
let fileLog = Log(category: "mcp", file: RotatingLogFile(directory: logsDirectory, name: "unfocused-mcp"))
let log: @Sendable (String) -> Void = { message in
  fileLog.info(message)
  try? stderrHandle.write(contentsOf: Data("unfocused-mcp: \(message)\n".utf8))
}

let databaseURL = FileManager.default.homeDirectoryForCurrentUser
  .appendingPathComponent("Library/Application Support/unfocused/unfocused.sqlite")
let backend = MCPServer.Backend.openReadOnly(at: databaseURL)
if case .unavailable(let message) = backend { log("Database not available: \(message)") }

var server = MCPServer(backend: backend, log: log)
while let line = readLine(strippingNewline: true) {
  guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
  if let response = server.handle(line: line) {
    print(response)
    fflush(stdout)
  }
}
