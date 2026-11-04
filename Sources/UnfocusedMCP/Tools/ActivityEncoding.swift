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

  /// Length of the range when the Agent names none: the last two hours.
  static let defaultRangeHours = 2

  static let rangeProperties: JSONValue = [
    "from": [
      "type": "string",
      "description":
        .string(
          "Optional start, ISO 8601 with offset, such as 2026-11-04T09:00:00+01:00. Defaults to \(defaultRangeHours) hours before 'to'."
        ),
    ],
    "to": [
      "type": "string",
      "description": "Optional end, ISO 8601 with offset. Defaults to now. At most 31 days after from.",
    ],
  ]

  /// The range asked for. Without arguments it is the last two hours, ending now.
  static func range(_ arguments: ToolArguments, now: Date) throws -> (from: Date, to: Date) {
    let to = try arguments.optionalString("to") == nil ? now : arguments.date("to")
    let from =
      try arguments.optionalString("from") == nil
      ? to.addingTimeInterval(-Double(defaultRangeHours) * 3_600) : arguments.date("from")
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
    fields["link"] = .string(stretch.anchor.link)
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
