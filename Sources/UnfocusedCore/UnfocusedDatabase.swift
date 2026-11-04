public import Foundation
import GRDB

/// The single local database of unfocused (ADR 0004).
///
/// All persistent state lives here. Schema changes only happen through
/// versioned migrations, so a database written by an older build always opens.
public final class UnfocusedDatabase: Sendable {
  let writer: any DatabaseWriter

  private init(writer: any DatabaseWriter, migrate: Bool = true) throws {
    self.writer = writer
    if migrate { try Self.migrator.migrate(writer) }
  }

  /// Opens (or creates) the database file at `url`, applying pending migrations.
  public static func open(at url: URL) throws -> UnfocusedDatabase {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    return try UnfocusedDatabase(writer: DatabasePool(path: url.path))
  }

  /// Opens an existing database for reading only, so a second process (such as `unfocused-mcp`) can
  /// read it safely next to the app. Never creates the file or its folder and never migrates; only
  /// the app does. Checks the schema first and throws a ``ReadOnlyDatabaseError`` saying what to do.
  public static func openReadOnly(at url: URL) throws -> UnfocusedDatabase {
    guard FileManager.default.fileExists(atPath: url.path) else { throw ReadOnlyDatabaseError.neverOpened }
    let queue = try readOnlyConnection(path: url.path)
    let state = try queue.read { db -> ReadOnlyDatabaseError? in
      if try migrator.appliedMigrations(db).isEmpty { return .neverOpened }
      if try migrator.hasBeenSuperseded(db) { return .superseded }
      if try !migrator.hasCompletedMigrations(db) { return .notYetMigrated }
      return nil
    }
    if let state { throw state }
    return try UnfocusedDatabase(writer: queue, migrate: false)
  }

  /// GRDB's `readonly` connection. Apple's SQLite cannot open a read-only WAL database whose `-wal`
  /// and `-shm` files are gone (they vanish when the app's last connection closes), so then it
  /// falls back to a connection that is allowed to create just those two files but is
  /// `query_only`: it still cannot change a single row, and it never creates the database.
  private static func readOnlyConnection(path: String) throws -> DatabaseQueue {
    var readonly = Configuration()
    readonly.readonly = true
    do {
      return try DatabaseQueue(path: path, configuration: readonly)
    } catch let error as DatabaseError where error.resultCode == .SQLITE_CANTOPEN {
      var queryOnly = Configuration()
      queryOnly.prepareDatabase { db in try db.execute(sql: "PRAGMA query_only = ON") }
      return try DatabaseQueue(path: path, configuration: queryOnly)
    }
  }

  /// A throwaway database that lives only in memory. Used by tests and previews.
  public static func inMemory() throws -> UnfocusedDatabase {
    try UnfocusedDatabase(writer: DatabaseQueue())
  }

  /// Closes the connections now. SQLite then removes the `-wal` and `-shm` files, if no other
  /// process has the database open. Using the database afterwards throws.
  public func close() throws {
    try writer.close()
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
    migrator.registerMigration("v8-engagement") { db in
      try db.alter(table: "loop") { table in
        table.add(column: "editedAt", .double)
      }
    }
    migrator.registerMigration("v9-judgements") { db in
      try db.create(table: "judgement") { table in
        table.column("identifier", .text).notNull()
        table.column("loopId", .text).notNull().references("loop", onDelete: .cascade)
        table.column("belongs", .boolean).notNull()
        table.column("judgedAt", .double).notNull()
        table.primaryKey(["identifier", "loopId"])
      }
    }
    return migrator
  }()
}

/// Why ``UnfocusedDatabase/openReadOnly(at:)`` refused, each with the action for the user.
public enum ReadOnlyDatabaseError: Error, Equatable, LocalizedError {
  /// There is no database yet.
  case neverOpened
  /// The app has not applied all migrations of this build yet.
  case notYetMigrated
  /// A newer build migrated the database past this one.
  case superseded

  public var errorDescription: String? {
    switch self {
    case .neverOpened: "There is no unfocused data yet. Open unfocused once."
    case .notYetMigrated: "unfocused has not finished updating its data. Open unfocused once to update."
    case .superseded: "The data was written by a newer unfocused. Update unfocused."
    }
  }
}
