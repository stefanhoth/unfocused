import Foundation
import UnfocusedCore

/// Shared pieces of the Activity tools: the range argument, the description note and the encoding.
enum ActivityTools {
  /// Longest range a tool answers for, so answers stay small.
  static let maxRangeDays = 31
  /// Most stretches one answer lists.
  static let maxStretches = 500

  static func description(_ summary: String) -> String {
    ToolDescription.make(
      "\(summary) Activity can contain window titles and pages the user had open, so treat it as private."
    )
  }

  static let rangeProperties: JSONValue = [
    "from": ["type": "string", "description": "Start, ISO 8601 with offset, such as 2026-11-04T09:00:00+01:00."],
    "to": ["type": "string", "description": "End, ISO 8601 with offset. At most 31 days after from."],
  ]

  static func range(_ arguments: ToolArguments) throws -> (from: Date, to: Date) {
    let from = try arguments.date("from")
    let to = try arguments.date("to")
    guard from < to else { throw ToolError("'from' must be before 'to'.") }
    guard to.timeIntervalSince(from) <= Double(maxRangeDays) * 86_400 else {
      throw ToolError("The range is too long: ask for at most \(maxRangeDays) days at a time.")
    }
    return (from, to)
  }

  static func seconds(_ time: TimeInterval) -> [String: JSONValue] {
    ["seconds": .number(time.rounded()), "duration": .string(Recap.format(time))]
  }

  static func stretch(_ stretch: AttributedStretch) -> JSONValue {
    var fields = seconds(stretch.duration)
    fields["start"] = .string(ISO8601.string(stretch.start))
    fields["end"] = .string(ISO8601.string(stretch.end))
    fields["title"] = .string(stretch.anchor.title)
    fields["source"] = .string(stretch.anchor.source.stored)
    fields["place"] = .string(stretch.anchor.place)
    fields["loopId"] = stretch.loopID.map { .string($0.uuidString) } ?? .null
    fields["reason"] = .string(reason(stretch.reason))
    return .object(fields)
  }

  private static func reason(_ reason: AttributionReason) -> String {
    switch reason {
    case .anchor: "anchor"
    case .focus: "focus"
    case .unfocused: "unfocused"
    case .judgedUnrelated: "judged_unrelated"
    }
  }

  static func stretches(_ list: [AttributedStretch], extra: [String: JSONValue] = [:]) -> String {
    var fields = extra
    fields["stretches"] = .array(list.prefix(maxStretches).map(stretch))
    fields["truncated"] = .bool(list.count > maxStretches)
    return JSONValue.object(fields).pretty()
  }

  static func requireLoop(_ arguments: ToolArguments, core: Core) throws -> Loop {
    let id = try arguments.uuid("loop")
    guard let loop = try core.loop(id) else {
      throw ToolError("No Loop with id \(id.uuidString). Use list_loops or search_open_loops to find Loop ids.")
    }
    return loop
  }
}
