import UnfocusedCore

/// Shared encoding of Core's answers for tool results.
extension Loop {
  var json: JSONValue {
    [
      "id": .string(id.uuidString),
      "title": .string(title),
      "state": .string(state.rawValue == "dropped" ? "let_go" : state.rawValue),
      "capturedAt": .string(ISO8601.string(capturedAt)),
      "whereILeftOff": whereILeftOff.map { .string($0) } ?? .null,
    ]
  }
}
