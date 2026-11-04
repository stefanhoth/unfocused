import Foundation

/// Any JSON value. The protocol layer and the tools speak this, so neither needs Codable models.
public enum JSONValue: Hashable, Sendable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])

  public var string: String? {
    if case .string(let value) = self { return value }
    return nil
  }

  public var object: [String: JSONValue]? {
    if case .object(let value) = self { return value }
    return nil
  }

  /// Parses UTF-8 JSON text. `nil` if it is not valid JSON.
  public init?(parsing text: String) {
    guard
      let parsed = try? JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed]),
      let value = JSONValue(foundation: parsed)
    else { return nil }
    self = value
  }

  private init?(foundation: Any) {
    switch foundation {
    case is NSNull:
      self = .null
    case let number as NSNumber:
      // NSNumber hides booleans; CFBoolean is the only reliable tell.
      if CFGetTypeID(number) == CFBooleanGetTypeID() {
        self = .bool(number.boolValue)
      } else {
        self = .number(number.doubleValue)
      }
    case let text as String:
      self = .string(text)
    case let items as [Any]:
      self = .array(items.compactMap { JSONValue(foundation: $0) })
    case let fields as [String: Any]:
      self = .object(fields.compactMapValues { JSONValue(foundation: $0) })
    default:
      return nil
    }
  }

  /// Compact JSON on one line (for the protocol), keys sorted so output is stable.
  public func compact() -> String { render(options: [.sortedKeys, .withoutEscapingSlashes]) }

  /// Indented JSON (for tool results the Agent reads as text), keys sorted.
  public func pretty() -> String { render(options: [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]) }

  private func render(options: JSONSerialization.WritingOptions) -> String {
    let data = try? JSONSerialization.data(withJSONObject: foundation, options: options.union(.fragmentsAllowed))
    return data.flatMap { String(data: $0, encoding: .utf8) } ?? "null"
  }

  private var foundation: Any {
    switch self {
    case .null: NSNull()
    case .bool(let value): value
    case .number(let value): value
    case .string(let value): value
    case .array(let items): items.map(\.foundation)
    case .object(let fields): fields.mapValues(\.foundation)
    }
  }
}

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral,
  ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral, ExpressibleByNilLiteral
{
  public init(stringLiteral value: String) { self = .string(value) }
  public init(dictionaryLiteral elements: (String, JSONValue)...) {
    self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
  }
  public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
  public init(booleanLiteral value: Bool) { self = .bool(value) }
  public init(integerLiteral value: Int) { self = .number(Double(value)) }
  public init(nilLiteral: ()) { self = .null }
}
