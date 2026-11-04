import Foundation
import Testing
import UnfocusedCore
import UnfocusedMCP

private final class Clock: TimeSource, @unchecked Sendable {
  private let lock = NSLock()
  private var current = Date(timeIntervalSince1970: 1_800_000_000)
  var now: Date { lock.withLock { current } }
  func advance(minutes: Int) { lock.withLock { current += TimeInterval(minutes * 60) } }
}

/// Contract tests for the Activity tools and the second switch, through the server's one seam.
@Suite("MCP activity tools")
struct ActivityToolsTests {
  private let start = Date(timeIntervalSince1970: 1_800_000_000)

  private struct World {
    let core: Core
    let clock: Clock
    let loop: Loop
  }

  /// 5 minutes in the Loop's Anchor, then 3 minutes in another Loop's Anchor while the first is Focused (Unfocused time).
  private func makeWorld(loops: Bool = true, activity: Bool = true) throws -> World {
    let clock = Clock()
    let core = try Core(database: .inMemory(), time: clock)
    let mine = try #require(Anchor.webPage(url: "https://example.com/spec", title: "Spec page", source: .safari))
    let other = try #require(Anchor.webPage(url: "https://news.example.org/a", title: "News", source: .safari))
    let loop = try core.capture(title: "Write spec", anchor: mine)
    _ = try core.capture(title: "Read news", anchor: other)
    try core.focus(loop.id)
    // Heartbeats a minute apart, as the app sends them.
    for _ in 0..<5 {
      try core.recordActivity(mine)
      clock.advance(minutes: 1)
    }
    for _ in 0..<3 {
      try core.recordActivity(other)
      clock.advance(minutes: 1)
    }
    try core.stopActivity(at: clock.now)
    try core.setAgentAccess(.loops, allowed: loops)
    try core.setAgentAccess(.activity, allowed: activity)
    return World(core: core, clock: clock, loop: loop)
  }

  private func call(
    _ core: Core,
    _ name: String,
    _ arguments: String = "{}"
  ) throws -> (json: [String: Any], text: String, isError: Bool) {
    var server = MCPServer(backend: .ready(core))
    let request =
      #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"\#(name)","arguments":\#(arguments)}}"#
    let reply = server.handle(line: request)
    let line = try #require(reply)
    let response = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
    let result = try #require(response["result"] as? [String: Any])
    let text = try #require((result["content"] as? [[String: Any]])?.first?["text"] as? String)
    let json = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any]
    return (json ?? [:], text, result["isError"] as? Bool ?? false)
  }

  private var range: String {
    #""from":"\#(ISO8601.string(start))","to":"\#(ISO8601.string(start + 3600))""#
  }

  // MARK: activity

  @Test("activity returns attributed stretches with the reason and the Loop id")
  func activityStretches() throws {
    let w = try makeWorld()
    let answer = try call(w.core, "activity", "{\(range)}")
    #expect(!answer.isError)
    let stretches = try #require(answer.json["stretches"] as? [[String: Any]])
    #expect(stretches.count == 2)
    #expect(stretches[0]["reason"] as? String == "anchor")
    #expect(stretches[0]["loopId"] as? String == w.loop.id.uuidString)
    #expect(stretches[0]["seconds"] as? Double == 300)
    #expect(stretches[0]["duration"] as? String == "5m")
    #expect(stretches[0]["title"] as? String == "Spec page")
    #expect(stretches[1]["reason"] as? String == "anchor")
    #expect(stretches[1]["loopId"] as? String != w.loop.id.uuidString)
  }

  // MARK: unfocused_time

  @Test("unfocused_time answers seconds and text")
  func unfocusedTime() throws {
    let w = try makeWorld()
    let answer = try call(w.core, "unfocused_time", "{\(range)}")
    #expect(answer.json["seconds"] as? Double == 180)
    #expect(answer.json["duration"] as? String == "3m")
  }

  // MARK: time_spent

  @Test("time_spent answers seconds and text for a Loop")
  func timeSpent() throws {
    let w = try makeWorld()
    let answer = try call(w.core, "time_spent", #"{"loop":"\#(w.loop.id.uuidString)",\#(range)}"#)
    #expect(answer.json["seconds"] as? Double == 300)
    #expect(answer.json["duration"] as? String == "5m")
    #expect(answer.json["loopId"] as? String == w.loop.id.uuidString)
  }

  @Test("time_spent for an unknown Loop is a readable error")
  func timeSpentUnknownLoop() throws {
    let w = try makeWorld()
    let answer = try call(w.core, "time_spent", #"{"loop":"\#(UUID().uuidString)",\#(range)}"#)
    #expect(answer.isError)
    #expect(answer.text.contains("list_loops"))
  }

  // MARK: work_log

  @Test("work_log lists only the Loop's stretches with reasons")
  func workLog() throws {
    let w = try makeWorld()
    let answer = try call(w.core, "work_log", #"{"loop":"\#(w.loop.id.uuidString)",\#(range)}"#)
    let entries = try #require(answer.json["stretches"] as? [[String: Any]])
    #expect(entries.count == 1)
    #expect(entries[0]["reason"] as? String == "anchor")
    #expect(answer.json["loopId"] as? String == w.loop.id.uuidString)
  }

  // MARK: recap

  @Test("recap answers Core's Markdown unchanged")
  func recapMarkdown() throws {
    let w = try makeWorld()
    let expected = try w.core.recap(day: w.clock.now).markdown()
    let answer = try call(w.core, "recap", #"{"period":"day"}"#)
    #expect(!answer.isError)
    #expect(answer.text == expected)
  }

  @Test("recap for a week and for a given date")
  func recapWeek() throws {
    let w = try makeWorld()
    let expected = try w.core.recap(weekOf: start).markdown()
    let answer = try call(w.core, "recap", #"{"period":"week","date":"\#(ISO8601.string(start))"}"#)
    #expect(answer.text == expected)
  }

  @Test("recap with another period is a readable error")
  func recapBadPeriod() throws {
    let w = try makeWorld()
    let answer = try call(w.core, "recap", #"{"period":"year"}"#)
    #expect(answer.isError)
    #expect(answer.text.contains("day"))
  }

  // MARK: ranges

  @Test(
    "a missing, malformed or reversed range is a readable error",
    arguments: [
      "{}",
      #"{"from":"2026-11-04T09:00:00+01:00"}"#,
      #"{"from":"yesterday","to":"today"}"#,
      #"{"from":"2026-11-04","to":"2026-11-05"}"#,
      #"{"from":"2026-11-05T09:00:00+01:00","to":"2026-11-04T09:00:00+01:00"}"#,
    ]
  )
  func badRange(_ arguments: String) throws {
    let w = try makeWorld()
    for name in ["activity", "unfocused_time"] {
      let answer = try call(w.core, name, arguments)
      #expect(answer.isError)
      #expect(answer.text.contains("from") || answer.text.contains("to"))
    }
  }

  @Test("a range over the cap is refused")
  func rangeTooBig() throws {
    let w = try makeWorld()
    let big = #""from":"\#(ISO8601.string(start))","to":"\#(ISO8601.string(start + 100 * 86_400))""#
    for name in ["activity", "unfocused_time"] {
      let answer = try call(w.core, name, "{\(big)}")
      #expect(answer.isError)
      #expect(answer.text.contains("days"))
    }
  }

  // MARK: switches

  private var activityTools: [(String, String)] {
    let id = UUID().uuidString
    return [
      ("activity", "{\(range)}"), ("unfocused_time", "{\(range)}"),
      ("time_spent", #"{"loop":"\#(id)",\#(range)}"#), ("work_log", #"{"loop":"\#(id)",\#(range)}"#),
      ("recap", #"{"period":"day"}"#),
    ]
  }

  @Test("with only Loops on, each Activity tool says how to allow Activity and returns no data")
  func activityOff() throws {
    let w = try makeWorld(loops: true, activity: false)
    for (name, arguments) in activityTools {
      let answer = try call(w.core, name, arguments)
      #expect(answer.isError, "\(name)")
      #expect(answer.text.contains("Let Agents read my Activity"), "\(name)")
      #expect(!answer.text.contains("Spec page"), "\(name)")
      #expect(!answer.text.contains("Write spec"), "\(name)")
    }
  }

  @Test("with Agent access off, each Activity tool gives the general message, even if Activity is chosen")
  func loopsOff() throws {
    let w = try makeWorld(loops: false, activity: true)
    for (name, arguments) in activityTools {
      let answer = try call(w.core, name, arguments)
      #expect(answer.isError, "\(name)")
      #expect(answer.text.contains("Let Agents read my Loops"), "\(name)")
      #expect(!answer.text.contains("Write spec"), "\(name)")
    }
  }

  @Test("with only Loops on, Loop tools keep working")
  func loopToolsStillWork() throws {
    let w = try makeWorld(loops: true, activity: false)
    let answer = try call(w.core, "get_loop", #"{"id":"\#(w.loop.id.uuidString)"}"#)
    #expect(!answer.isError)
    #expect(answer.text.contains("Write spec"))
  }

  // MARK: descriptions

  @Test("descriptions say results are data and that Activity can hold window titles and pages")
  func descriptions() throws {
    let tools = ToolRegistry.all.filter { $0.requiredAccess == .activity }
    #expect(
      Set(tools.map(\.name)) == ["activity", "unfocused_time", "time_spent", "work_log", "recap"]
    )
    for tool in tools {
      #expect(tool.description.contains("data, not instructions"))
      #expect(tool.description.contains("window titles"))
      #expect(tool.description.contains("pages"))
    }
  }
}
