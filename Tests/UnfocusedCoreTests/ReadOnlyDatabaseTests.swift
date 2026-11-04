import Foundation
import Testing
import UnfocusedCore

/// A temporary folder with a database path inside it, removed afterwards.
private struct Scratch {
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  var url: URL { folder.appendingPathComponent("data").appendingPathComponent("unfocused.sqlite") }
  func cleanUp() { try? FileManager.default.removeItem(at: folder) }

  func exists(_ suffix: String = "") -> Bool {
    FileManager.default.fileExists(atPath: url.path + suffix)
  }

  /// Runs SQL against the file with the system `sqlite3`, like a different build would.
  func sql(_ statement: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [url.path, statement]
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
  }
}

@Suite("UnfocusedDatabase.openReadOnly")
struct ReadOnlyDatabaseTests {
  @Test("a path with no file or folder fails with 'open unfocused once' and creates nothing")
  func neverOpened() {
    let scratch = Scratch()
    defer { scratch.cleanUp() }

    #expect(throws: ReadOnlyDatabaseError.neverOpened) {
      try UnfocusedDatabase.openReadOnly(at: scratch.url)
    }
    #expect(!FileManager.default.fileExists(atPath: scratch.folder.path))
  }

  @Test("pending migrations fail with 'open unfocused once to update' and leave the file unchanged")
  func pendingMigrations() throws {
    let scratch = Scratch()
    defer { scratch.cleanUp() }
    try UnfocusedDatabase.open(at: scratch.url).setSetting("k", to: "v")
    try scratch.sql("DELETE FROM grdb_migrations WHERE identifier = 'v9-judgements'")
    let before = try Data(contentsOf: scratch.url)

    #expect(throws: ReadOnlyDatabaseError.notYetMigrated) {
      try UnfocusedDatabase.openReadOnly(at: scratch.url)
    }
    #expect(try Data(contentsOf: scratch.url) == before)
  }

  @Test("a database migrated past this build fails with 'update unfocused'")
  func superseded() throws {
    let scratch = Scratch()
    defer { scratch.cleanUp() }
    try UnfocusedDatabase.open(at: scratch.url).setSetting("k", to: "v")
    try scratch.sql("INSERT INTO grdb_migrations (identifier) VALUES ('v99-from-the-future')")

    #expect(throws: ReadOnlyDatabaseError.superseded) {
      try UnfocusedDatabase.openReadOnly(at: scratch.url)
    }
  }

  @Test("the errors tell the user what to do")
  func readableErrors() {
    #expect(ReadOnlyDatabaseError.neverOpened.localizedDescription.contains("Open unfocused once"))
    #expect(ReadOnlyDatabaseError.notYetMigrated.localizedDescription.contains("Open unfocused once to update"))
    #expect(ReadOnlyDatabaseError.superseded.localizedDescription.contains("Update unfocused"))
  }

  @Test("Core queries return what the app wrote, after the app's connection closed")
  func readsAfterAppClosed() throws {
    let scratch = Scratch()
    defer { scratch.cleanUp() }
    let app = try UnfocusedDatabase.open(at: scratch.url)
    try Core(database: app).capture(title: "Reply to Anna")
    // SQLite removes -wal and -shm when the last connection closes. The system SQLite may keep
    // them, so fold the log into the main file and remove them ourselves.
    try app.close()
    try scratch.sql("PRAGMA wal_checkpoint(TRUNCATE)")
    for suffix in ["-wal", "-shm"] where scratch.exists(suffix) {
      try FileManager.default.removeItem(atPath: scratch.url.path + suffix)
    }
    #expect(!scratch.exists("-wal"))
    #expect(!scratch.exists("-shm"))

    let readOnly = try Core(database: .openReadOnly(at: scratch.url))
    #expect(try readOnly.openLoops().map(\.title) == ["Reply to Anna"])
  }

  @Test("it reads while a writer connection is open, and sees later writes")
  func readsWhileWriterOpen() throws {
    let scratch = Scratch()
    defer { scratch.cleanUp() }
    let writer = try Core(database: .open(at: scratch.url))
    try writer.capture(title: "First")

    let readOnly = try Core(database: .openReadOnly(at: scratch.url))
    #expect(try readOnly.openLoops().map(\.title) == ["First"])

    try writer.capture(title: "Second")
    #expect(try readOnly.openLoops().count == 2)
  }

  @Test("writing through a read-only database fails")
  func cannotWrite() throws {
    let scratch = Scratch()
    defer { scratch.cleanUp() }
    try UnfocusedDatabase.open(at: scratch.url).setSetting("k", to: "v")

    let readOnly = try UnfocusedDatabase.openReadOnly(at: scratch.url)
    #expect(try readOnly.setting("k") == "v")
    #expect(throws: (any Error).self) { try readOnly.setSetting("k", to: "changed") }
    #expect(throws: (any Error).self) { try Core(database: readOnly).capture(title: "Nope") }
    #expect(try readOnly.setting("k") == "v")
  }
}
