import Foundation
import Testing
import UnfocusedCore

@Suite("Importing People")
struct PeopleImportTests {
  @Test("one name per line becomes one Person each")
  func lines() throws {
    let (core, _) = try makeCore()

    let result = try core.importPeople("Anna Schmidt\n\nBen Okafor\n  Cleo Park  \n")

    #expect(result.added.map(\.name) == ["Anna Schmidt", "Ben Okafor", "Cleo Park"])
    #expect(try core.people().map(\.name) == ["Anna Schmidt", "Ben Okafor", "Cleo Park"])
  }

  @Test("CSV uses the first column and skips a header")
  func csv() throws {
    let (core, _) = try makeCore()

    let result = try core.importPeople("Name,Company\n\"Anna Schmidt\",ACME\nBen Okafor,Initech\n")

    #expect(result.added.map(\.name) == ["Anna Schmidt", "Ben Okafor"])
  }

  @Test("exact duplicates, ignoring case and accents, are merged automatically")
  func exactDuplicates() throws {
    let (core, _) = try makeCore()
    _ = try core.importPeople("Jörg Müller")

    let result = try core.importPeople("jorg muller\nJÖRG MÜLLER\nAnna\nanna")

    #expect(result.added.map(\.name) == ["Anna"])
    #expect(result.skippedDuplicates == 3)
    #expect(try core.people().count == 2)
  }

  @Test("re-importing the same list adds nobody")
  func reimport() throws {
    let (core, _) = try makeCore()
    let list = "Anna Schmidt\nBen Okafor"
    _ = try core.importPeople(list)

    let again = try core.importPeople(list)

    #expect(again.added.isEmpty)
    #expect(try core.people().count == 2)
  }

  @Test("near-duplicates are held back for the user to decide")
  func nearDuplicates() throws {
    let (core, _) = try makeCore()
    let john = try #require(try core.importPeople("John Smith").added.first)

    let result = try core.importPeople("Jon Smith\nMaria Garcia")

    #expect(result.added.map(\.name) == ["Maria Garcia"])
    #expect(result.nearMatches == [NearMatch(name: "Jon Smith", existing: john)])
  }

  @Test("keeping a near-duplicate adds it as a separate Person")
  func keepNearDuplicate() throws {
    let (core, _) = try makeCore()
    _ = try core.importPeople("John Smith")

    let jon = try core.addPerson(named: "Jon Smith", evenIfSimilar: true)

    #expect(jon.name == "Jon Smith")
    #expect(try core.people().count == 2)
  }
}

@Suite("Managing People")
struct PeopleManagementTests {
  @Test("adding a name that exists returns the existing Person")
  func addExisting() throws {
    let (core, _) = try makeCore()
    let anna = try core.addPerson(named: "Anna")

    #expect(try core.addPerson(named: " anna ") == anna)
    #expect(try core.people().count == 1)
  }

  @Test("People can be renamed and deleted")
  func renameDelete() throws {
    let (core, _) = try makeCore()
    let anna = try core.addPerson(named: "Ana")

    try core.rename(anna.id, to: "Anna")
    #expect(try core.people().map(\.name) == ["Anna"])

    try core.deletePerson(anna.id)
    #expect(try core.people().isEmpty)
  }

  @Test("merging moves a Person's Loops to the other Person")
  func merge() throws {
    let (core, _) = try makeCore()
    let jon = try core.addPerson(named: "Jon Smith")
    let john = try core.addPerson(named: "John Smith", evenIfSimilar: true)
    let loop = try core.capture(title: "Reply")
    try core.involve(jon.id, in: loop.id, as: .waiting)

    try core.merge(jon.id, into: john.id)

    #expect(try core.people().map(\.name) == ["John Smith"])
    #expect(try core.people(of: loop.id) == [Involvement(person: john, direction: .waiting)])
  }

  @Test("autocomplete finds People by any part of their name")
  func autocomplete() throws {
    let (core, _) = try makeCore()
    _ = try core.importPeople("Anna Schmidt\nBen Okafor\nJohanna Lee")

    #expect(try core.searchPeople("schm").map(\.name) == ["Anna Schmidt"])
    #expect(try core.searchPeople("ann").first?.name == "Anna Schmidt")
  }
}

@Suite("People on Loops")
struct InvolvementTests {
  @Test("a Person is involved as Owed or Waiting, and can be switched")
  func directions() throws {
    let (core, _) = try makeCore()
    let anna = try core.addPerson(named: "Anna")
    let loop = try core.capture(title: "Contract")

    try core.involve(anna.id, in: loop.id, as: .owed)
    #expect(try core.people(of: loop.id) == [Involvement(person: anna, direction: .owed)])

    try core.involve(anna.id, in: loop.id, as: .waiting)
    #expect(try core.people(of: loop.id) == [Involvement(person: anna, direction: .waiting)])

    try core.removePerson(anna.id, from: loop.id)
    #expect(try core.people(of: loop.id).isEmpty)
  }

  @Test("all Loops involving a Person can be listed")
  func loopsOfPerson() throws {
    let (core, _) = try makeCore()
    let anna = try core.addPerson(named: "Anna")
    let one = try core.capture(title: "One")
    _ = try core.capture(title: "Two")
    try core.involve(anna.id, in: one.id, as: .owed)

    #expect(try core.loops(involving: anna.id).map(\.id) == [one.id])
  }

  @Test("capturing with @mentions involves those People and keeps the names in the title")
  func mentions() throws {
    let (core, _) = try makeCore()
    let anna = try core.addPerson(named: "Anna Schmidt")

    let loop = try core.capture(title: "Send @Anna Schmidt the numbers, ask @Ben")

    #expect(loop.title == "Send Anna Schmidt the numbers, ask Ben")
    let involved = try core.people(of: loop.id)
    #expect(involved.map(\.person.name) == ["Anna Schmidt", "Ben"])
    #expect(involved.first?.person == anna)
    #expect(involved.allSatisfy { $0.direction == .owed })
  }

  @Test("the panel can preview which names a title mentions")
  func previewMentions() throws {
    let (core, _) = try makeCore()
    _ = try core.addPerson(named: "Anna Schmidt")

    #expect(try core.mentionedNames(in: "Ask @anna schmidt and @Ben. Email me@example.com") == ["Anna Schmidt", "Ben"])
  }

  @Test("mentions can carry a direction")
  func mentionDirections() throws {
    let (core, _) = try makeCore()

    let loop = try core.capture(title: "Contract @Anna", directions: ["Anna": .waiting])

    #expect(try core.people(of: loop.id).map(\.direction) == [.waiting])
  }
}
