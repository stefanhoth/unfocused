import Foundation
import UnfocusedCore

/// Wires Core to the real file system locations on this Mac.
struct AppEnvironment {
  let database: UnfocusedDatabase
  let log: Log

  static func live(fileManager: FileManager = .default) throws -> AppEnvironment {
    let support = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    .appendingPathComponent("unfocused", isDirectory: true)
    let logs = fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Logs/unfocused", isDirectory: true)

    let log = Log(category: "app", file: RotatingLogFile(directory: logs))
    let database = try UnfocusedDatabase.open(at: support.appendingPathComponent("unfocused.sqlite"))
    return AppEnvironment(database: database, log: log)
  }
}
