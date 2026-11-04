import UnfocusedCore

/// Shared encoding of Core's answers for tool results.
extension Loop {
  var json: JSONValue {
    [
      "id": .string(id.uuidString),
      "title": .string(title),
      "state": .string(stateName),
      "capturedAt": .string(ISO8601.string(capturedAt)),
      "whereILeftOff": whereILeftOff.map { .string($0) } ?? .null,
    ]
  }
}

extension Loop {
  fileprivate var stateName: String {
    switch state {
    case .open: "open"
    case .closed: "closed"
    case .letGo: "let_go"
    }
  }
}
