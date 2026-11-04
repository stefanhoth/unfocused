import Foundation
public import UnfocusedCore

/// A Person's Open Loops, with the direction (Owed or Waiting).
public struct LoopsInvolvingTool: MCPTool {
  public init() {}

  public let name = "loops_involving"
  public let description = ToolDescription.make(
    "Lists only the Open Loops (not Closed or Let go ones) a Person is involved in, each with its direction: owed (the Person is waiting on the user) or waiting (the user is waiting on the Person). The name may be partial and in any case. If several People match, even when one matches exactly, the candidates are returned instead of a guess: ask the user which one is meant."
  )
  public let inputSchema: JSONValue = [
    "type": "object",
    "properties": ["person": ["type": "string", "description": "A name or part of a name."]],
    "required": ["person"],
  ]

  public func call(arguments: ToolArguments, core: Core) throws -> String {
    let query = try arguments.string("person").trimmingCharacters(in: .whitespacesAndNewlines)
    let matches = try core.searchPeople(query)
    guard !matches.isEmpty else {
      return JSONValue.object(["message": .string("No Person called \"\(query)\".")]).pretty()
    }
    // An exact name never wins silently: "Anna" also matches "Anna Schmidt", so the user decides.
    guard matches.count == 1, let person = matches.first else {
      return JSONValue.object([
        "message": .string("\(matches.count) People match \"\(query)\". Which one is meant? Ask the user."),
        "candidates": .array(matches.map(\.json)),
      ]).pretty()
    }
    let loops: [JSONValue] = try core.loops(involving: person.id)
      .filter { $0.state == .open }
      .map { loop in
        let direction = try core.people(of: loop.id).first { $0.person.id == person.id }?.direction
        var json = loop.json.object ?? [:]
        json["direction"] = direction.map { .string($0.rawValue) } ?? .null
        return .object(json)
      }
    return JSONValue.object(["person": person.json, "loops": .array(loops)]).pretty()
  }
}
