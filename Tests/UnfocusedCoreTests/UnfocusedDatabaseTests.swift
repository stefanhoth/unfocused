import Foundation
import Testing
import UnfocusedCore

@Suite("UnfocusedDatabase")
struct UnfocusedDatabaseTests {
  @Test("a new database has all migrations applied")
  func appliesMigrations() throws {
    let database = try UnfocusedDatabase.inMemory()
    #expect(try database.appliedMigrations() == ["v1-settings", "v2-loops", "v3-focus", "v4-lifecycle"])
  }

  @Test("settings can be stored, replaced and removed")
  func settingsRoundTrip() throws {
    let database = try UnfocusedDatabase.inMemory()
    #expect(try database.setting("hotkey") == nil)

    try database.setSetting("hotkey", to: "ctrl+space")
    try database.setSetting("hotkey", to: "ctrl+opt+space")
    #expect(try database.setting("hotkey") == "ctrl+opt+space")

    try database.setSetting("hotkey", to: nil)
    #expect(try database.setting("hotkey") == nil)
  }

  @Test("a database file keeps its data when reopened")
  func reopensFile() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("unfocused.sqlite")
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    try UnfocusedDatabase.open(at: url).setSetting("looseEndDays", to: "3")
    let reopened = try UnfocusedDatabase.open(at: url)

    #expect(try reopened.setting("looseEndDays") == "3")
    #expect(try reopened.appliedMigrations() == ["v1-settings", "v2-loops", "v3-focus", "v4-lifecycle"])
  }
}
