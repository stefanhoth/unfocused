public import Foundation
import GRDB

/// Someone involved in a Loop (see GLOSSARY.md).
public struct Person: Identifiable, Hashable, Sendable {
  public let id: UUID
  public var name: String

  public init(id: UUID, name: String) {
    self.id = id
    self.name = name
  }
}

/// Which way a Loop points between the user and a Person.
public enum Direction: String, Sendable, CaseIterable {
  /// The Person is waiting on the user.
  case owed
  /// The user is waiting on the Person.
  case waiting

  public var toggled: Direction { self == .owed ? .waiting : .owed }
}

public struct Involvement: Hashable, Sendable {
  public let person: Person
  public let direction: Direction

  public init(person: Person, direction: Direction) {
    self.person = person
    self.direction = direction
  }
}

/// An imported name that looks like an existing Person ("Jon Smith" vs "John Smith").
public struct NearMatch: Hashable, Sendable {
  public let name: String
  public let existing: Person

  public init(name: String, existing: Person) {
    self.name = name
    self.existing = existing
  }
}

public struct PeopleImport: Sendable {
  public let added: [Person]
  /// Names that matched an existing Person exactly (ignoring case and accents).
  public let skippedDuplicates: Int
  /// Names held back because they're similar to an existing Person.
  public let nearMatches: [NearMatch]
}

/// Name comparison rules: exact matches ignore case, accents and extra spaces;
/// near matches are a typo or two apart.
enum NameMatching {
  static func key(_ name: String) -> String {
    name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
  }

  static func isNear(_ lhs: String, _ rhs: String) -> Bool {
    let a = Array(key(lhs))
    let b = Array(key(rhs))
    guard a != b else { return false }
    let allowed = min(a.count, b.count) < 8 ? 1 : 2
    guard abs(a.count - b.count) <= allowed else { return false }
    return distance(a, b) <= allowed
  }

  /// Levenshtein distance.
  private static func distance(_ a: [Character], _ b: [Character]) -> Int {
    var previous = Array(0...b.count)
    for (i, ca) in a.enumerated() {
      var current = [i + 1]
      for (j, cb) in b.enumerated() {
        current.append(Swift.min(previous[j + 1] + 1, current[j] + 1, previous[j] + (ca == cb ? 0 : 1)))
      }
      previous = current
    }
    return previous[b.count]
  }

  /// Names from a pasted list or file: one per line, or the first column of a CSV.
  static func parseList(_ text: String) -> [String] {
    var names = text.split(whereSeparator: \.isNewline).compactMap { line -> String? in
      var field = String(line)
      if let comma = firstUnquotedComma(in: field) { field = String(field[..<comma]) }
      field = field.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
      field = field.trimmingCharacters(in: .whitespaces)
      return field.isEmpty ? nil : field
    }
    if let first = names.first, ["name", "names", "full name"].contains(key(first)) { names.removeFirst() }
    return names
  }

  private static func firstUnquotedComma(in line: String) -> String.Index? {
    var quoted = false
    for index in line.indices {
      switch line[index] {
      case "\"": quoted.toggle()
      case "," where !quoted: return index
      default: continue
      }
    }
    return nil
  }
}

struct PersonRecord: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "person"

  var id: String
  var name: String
  var key: String

  init(_ person: Person) {
    id = person.id.uuidString
    name = person.name
    key = NameMatching.key(person.name)
  }

  var person: Person { Person(id: UUID(uuidString: id) ?? UUID(), name: name) }
}

struct InvolvementRecord: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "involvement"

  var loopId: String
  var personId: String
  var direction: String
}

extension Core {
  // MARK: People commands

  /// Imports a pasted or dropped list of names. Exact duplicates are skipped; near-duplicates are
  /// returned for the user to decide (keep with `addPerson(named:evenIfSimilar:)`, or ignore to merge).
  public func importPeople(_ text: String) throws -> PeopleImport {
    try database.writer.write { db in
      var known = try PersonRecord.fetchAll(db).map(\.person)
      var added: [Person] = []
      var skipped = 0
      var near: [NearMatch] = []
      for name in NameMatching.parseList(text) {
        if known.contains(where: { NameMatching.key($0.name) == NameMatching.key(name) }) {
          skipped += 1
        } else if let similar = known.first(where: { NameMatching.isNear($0.name, name) }) {
          near.append(NearMatch(name: name, existing: similar))
        } else {
          let person = Person(id: UUID(), name: name)
          try PersonRecord(person).insert(db)
          known.append(person)
          added.append(person)
        }
      }
      return PeopleImport(added: added, skippedDuplicates: skipped, nearMatches: near)
    }
  }

  /// Returns the Person with this name, creating them if needed. Throws `similarPersonExists`
  /// when a near-duplicate exists, unless `evenIfSimilar` is set.
  @discardableResult
  public func addPerson(named name: String, evenIfSimilar: Bool = false) throws -> Person {
    try database.writer.write { db in try Self.person(named: name, evenIfSimilar: evenIfSimilar, db) }
  }

  public func rename(_ personID: UUID, to name: String) throws {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw CoreError.emptyTitle }
    try database.writer.write { db in
      guard var record = try PersonRecord.fetchOne(db, key: personID.uuidString) else {
        throw CoreError.personNotFound
      }
      record.name = trimmed
      record.key = NameMatching.key(trimmed)
      try record.update(db)
    }
  }

  public func deletePerson(_ personID: UUID) throws {
    try database.writer.write { db in
      _ = try InvolvementRecord.filter(Column("personId") == personID.uuidString).deleteAll(db)
      _ = try PersonRecord.deleteOne(db, key: personID.uuidString)
    }
  }

  /// Moves everything of `duplicate` to `person`, then deletes `duplicate`.
  public func merge(_ duplicate: UUID, into person: UUID) throws {
    try database.writer.write { db in
      guard try PersonRecord.fetchOne(db, key: person.uuidString) != nil else { throw CoreError.personNotFound }
      let moved = try InvolvementRecord.filter(Column("personId") == duplicate.uuidString).fetchAll(db)
      for var involvement in moved {
        try involvement.delete(db)
        involvement.personId = person.uuidString
        try involvement.insert(db, onConflict: .ignore)
      }
      _ = try PersonRecord.deleteOne(db, key: duplicate.uuidString)
    }
  }

  /// Adds a Person to a Loop, or changes their direction if they're already on it.
  public func involve(_ personID: UUID, in loopID: UUID, as direction: Direction) throws {
    try database.writer.write { db in
      guard try LoopRecord.fetchOne(db, key: loopID.uuidString) != nil else { throw CoreError.loopNotFound }
      guard try PersonRecord.fetchOne(db, key: personID.uuidString) != nil else { throw CoreError.personNotFound }
      try InvolvementRecord(loopId: loopID.uuidString, personId: personID.uuidString, direction: direction.rawValue)
        .insert(db, onConflict: .replace)
    }
  }

  public func removePerson(_ personID: UUID, from loopID: UUID) throws {
    try database.writer.write { db in
      _ =
        try InvolvementRecord
        .filter(Column("loopId") == loopID.uuidString && Column("personId") == personID.uuidString)
        .deleteAll(db)
    }
  }

  // MARK: People queries

  /// The names that `@` mentions in `text` resolve to, as Capture would see them.
  public func mentionedNames(in text: String) throws -> [String] {
    Mentions.parse(text, knownNames: try people().map(\.name)).names
  }

  /// Everyone, by name.
  public func people() throws -> [Person] {
    try database.writer.read { db in
      try PersonRecord.order(Column("key")).fetchAll(db).map(\.person)
    }
  }

  /// People matching `query` fuzzily, best first. For @mention autocomplete.
  public func searchPeople(_ query: String) throws -> [Person] {
    let everyone = try people()
    guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return everyone }
    return
      everyone
      .compactMap { person in FuzzyMatch.score(query: query, in: person.name).map { (person, $0) } }
      .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.name < $1.0.name }
      .map(\.0)
  }

  /// The People on a Loop, in the order they were added.
  public func people(of loopID: UUID) throws -> [Involvement] {
    try database.writer.read { db in
      let rows = try InvolvementRecord.filter(Column("loopId") == loopID.uuidString).order(Column("rowid")).fetchAll(db)
      return try rows.compactMap { row in
        guard let person = try PersonRecord.fetchOne(db, key: row.personId)?.person else { return nil }
        return Involvement(person: person, direction: Direction(rawValue: row.direction) ?? .owed)
      }
    }
  }

  /// Loops a Person is involved in, any state, newest first.
  public func loops(involving personID: UUID) throws -> [Loop] {
    try database.writer.read { db in
      let ids = try String.fetchAll(
        db,
        sql: "SELECT loopId FROM involvement WHERE personId = ?",
        arguments: [personID.uuidString]
      )
      return try LoopRecord.filter(keys: ids).order(Column("capturedAt").desc).fetchAll(db).map(\.loop)
    }
  }

  // MARK: Helpers

  static func person(named name: String, evenIfSimilar: Bool, _ db: Database) throws -> Person {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw CoreError.emptyTitle }
    let key = NameMatching.key(trimmed)
    if let existing = try PersonRecord.filter(Column("key") == key).fetchOne(db) { return existing.person }
    if !evenIfSimilar,
      let similar = try PersonRecord.fetchAll(db).first(where: { NameMatching.isNear($0.name, trimmed) })
    {
      throw CoreError.similarPersonExists(similar.person)
    }
    let person = Person(id: UUID(), name: trimmed)
    try PersonRecord(person).insert(db)
    return person
  }
}
