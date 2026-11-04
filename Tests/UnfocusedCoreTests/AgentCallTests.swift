import Foundation
import Testing

@testable import UnfocusedCore

/// The record of an Agent's call (ADR 0007, DECISIONS 2026-11-04): what the log line and the hand-off
/// file hold, and what they must never hold.
@Suite("Agent call record")
struct AgentCallTests {
  private let when = Date(timeIntervalSince1970: 1_793_800_000)

  private func tempDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("agent-call-\(UUID().uuidString)")
  }

  @Test("an answered call logs time, Agent and tool")
  func answeredLine() {
    let call = AgentCall(date: when, agent: "Claude Code", tool: "list_loops", refused: false)
    #expect(call.logLine == "tools/call list_loops by Claude Code")
  }

  @Test("a refused call is logged as refused")
  func refusedLine() {
    let call = AgentCall(date: when, agent: "Claude Code", tool: "list_loops", refused: true)
    #expect(call.logLine == "tools/call list_loops by Claude Code (refused: access was off)")
  }

  @Test("an Agent that sent no name is unknown; blank or control-laden names are cleaned")
  func names() {
    #expect(AgentCall(date: when, agent: nil, tool: "x", refused: false).agent == "unknown")
    #expect(AgentCall(date: when, agent: "  ", tool: "x", refused: false).agent == "unknown")
    #expect(AgentCall(date: when, agent: "Bad\nName\t!", tool: "x", refused: false).agent == "Bad Name !")
    #expect(
      AgentCall(date: when, agent: String(repeating: "a", count: 500), tool: "x", refused: false).agent.count == 60
    )
  }

  @Test("the store keeps only the last call and reads it back")
  func storeRoundTrip() throws {
    let store = AgentCallStore(directory: tempDirectory())
    #expect(store.last() == nil)
    store.record(AgentCall(date: when, agent: "A", tool: "focused_loop", refused: false))
    store.record(AgentCall(date: when.addingTimeInterval(5), agent: "B", tool: "loose_ends", refused: true))
    let last = try #require(store.last())
    #expect(last.agent == "B")
    #expect(last.tool == "loose_ends")
    #expect(last.refused)
    #expect(abs(last.date.timeIntervalSince(when.addingTimeInterval(5))) < 1)
  }

  @Test("the file holds only time, Agent, tool and the refused flag")
  func fileContents() throws {
    let store = AgentCallStore(directory: tempDirectory())
    store.record(AgentCall(date: when, agent: "A", tool: "get_loop", refused: false))
    let data = try Data(contentsOf: store.fileURL)
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(Set(object.keys) == ["date", "agent", "tool", "refused"])
  }

  @Test("an unreadable or missing file means never used")
  func unreadable() throws {
    let directory = tempDirectory()
    let store = AgentCallStore(directory: directory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: store.fileURL)
    #expect(store.last() == nil)
  }
}
