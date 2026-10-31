public import Foundation
import GRDB

/// The single local database of unfocused (ADR 0004).
///
/// All persistent state lives here. Schema changes only happen through
/// versioned migrations, so a database written by an older build always opens.
public final class UnfocusedDatabase: Sendable {
  let writer: any DatabaseWriter

  private init(writer: any DatabaseWriter) throws {
    self.writer = writer
    try Self.migrator.migrate(writer)
  }

  /// Opens (or creates) the database file at `url`, applying pending migrations.
  public static func open(at url: URL) throws -> UnfocusedDatabase {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    return try UnfocusedDatabase(writer: DatabasePool(path: url.path))
  }

  /// A throwaway database that lives only in memory. Used by tests and previews.
  public static func inMemory() throws -> UnfocusedDatabase {
    try UnfocusedDatabase(writer: DatabaseQueue())
  }

  /// Identifiers of all migrations applied to this database, oldest first.
  public func appliedMigrations() throws -> [String] {
    try writer.read { db in try Self.migrator.appliedMigrations(db) }
  }

  // MARK: Settings

  /// The stored value for a setting, or `nil` if it was never set.
  public func setting(_ key: String) throws -> String? {
    try writer.read { db in
      try String.fetchOne(db, sql: "SELECT value FROM setting WHERE key = ?", arguments: [key])
    }
  }

  /// Stores `value` for `key`, replacing any previous value. `nil` removes it.
  public func setSetting(_ key: String, to value: String?) throws {
    try writer.write { db in
      if let value {
        try db.execute(
          sql: "INSERT INTO setting (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
          arguments: [key, value]
        )
      } else {
        try db.execute(sql: "DELETE FROM setting WHERE key = ?", arguments: [key])
      }
    }
  }

  // MARK: Schema

  private static let migrator: DatabaseMigrator = {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("v1-settings") { db in
      try db.create(table: "setting") { table in
        table.primaryKey("key", .text)
        table.column("value", .text).notNull()
      }
    }
    migrator.registerMigration("v2-loops") { db in
      try db.create(table: "loop") { table in
        table.primaryKey("id", .text)
        table.column("title", .text).notNull()
        table.column("state", .text).notNull()
        table.column("capturedAt", .double).notNull().indexed()
      }
    }
    migrator.registerMigration("v3-focus") { db in
      try db.alter(table: "loop") { table in
        table.add(column: "whereILeftOff", .text)
      }
      try db.create(table: "focusSession") { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("loopId", .text).notNull().indexed().references("loop", onDelete: .cascade)
        table.column("start", .double).notNull()
        table.column("end", .double)
      }
    }
    migrator.registerMigration("v4-lifecycle") { db in
      try db.alter(table: "loop") { table in
        table.add(column: "stateChangedAt", .double).notNull().defaults(to: 0)
      }
      try db.execute(sql: "UPDATE loop SET stateChangedAt = capturedAt")
      try db.create(table: "loopEvent") { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("loopId", .text).notNull().indexed().references("loop", onDelete: .cascade)
        table.column("change", .text).notNull()
        table.column("at", .double).notNull()
      }
      try db.execute(sql: "INSERT INTO loopEvent (loopId, change, at) SELECT id, 'captured', capturedAt FROM loop")
    }
    migrator.registerMigration("v5-anchors") { db in
      try db.create(table: "anchor") { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("loopId", .text).notNull().indexed().references("loop", onDelete: .cascade)
        table.column("source", .text).notNull()
        table.column("identifier", .text).notNull().indexed()
        table.column("link", .text).notNull()
        table.column("title", .text).notNull()
        table.column("addedAt", .double).notNull()
      }
    }
    migrator.registerMigration("v6-people") { db in
      try db.create(table: "person") { table in
        table.primaryKey("id", .text)
        table.column("name", .text).notNull()
        table.column("key", .text).notNull().unique()
      }
      try db.create(table: "involvement") { table in
        table.column("loopId", .text).notNull().references("loop", onDelete: .cascade)
        table.column("personId", .text).notNull().indexed().references("person", onDelete: .cascade)
        table.column("direction", .text).notNull()
        table.primaryKey(["loopId", "personId"])
      }
    }
    migrator.registerMigration("v7-activity") { db in
      try db.create(table: "activity") { table in
        table.autoIncrementedPrimaryKey("id")
        table.column("source", .text).notNull()
        table.column("identifier", .text).notNull().indexed()
        table.column("link", .text).notNull()
        table.column("title", .text).notNull()
        table.column("start", .double).notNull().indexed()
        table.column("lastSeen", .double).notNull().indexed()
        table.column("closed", .boolean).notNull().defaults(to: false)
      }
    }
    return migrator
  }()
}
