import Foundation
import GRDB

/// Non-content facts about the local data, for a diagnostics bundle: counts and schema, never
/// titles, names, Anchors or Activity.
public struct Diagnostics: Codable, Hashable, Sendable {
  public let migrations: [String]
  public let loopsByState: [String: Int]
  public let anchors: Int
  public let people: Int
  public let activityStretches: Int
  public let focusSessions: Int
  public let settingKeys: [String]
}

extension Core {
  public func diagnostics() throws -> Diagnostics {
    let migrations = try database.appliedMigrations()
    return try database.writer.read { db in
      var byState: [String: Int] = [:]
      for state in LoopState.allCases {
        byState[state.rawValue] = try LoopRecord.filter(Column("state") == state.rawValue).fetchCount(db)
      }
      return Diagnostics(
        migrations: migrations,
        loopsByState: byState,
        anchors: try AnchorRecord.fetchCount(db),
        people: try PersonRecord.fetchCount(db),
        activityStretches: try ActivityRecord.fetchCount(db),
        focusSessions: try FocusSessionRecord.fetchCount(db),
        settingKeys: try String.fetchAll(db, sql: "SELECT key FROM setting ORDER BY key")
      )
    }
  }
}

extension CoreError: CustomStringConvertible {
  /// Content-free, so errors can be logged without leaking names.
  public var description: String {
    switch self {
    case .emptyTitle: "emptyTitle"
    case .loopNotFound: "loopNotFound"
    case .loopNotOpen: "loopNotOpen"
    case .invalidStateChange: "invalidStateChange"
    case .personNotFound: "personNotFound"
    case .similarPersonExists: "similarPersonExists"
    }
  }
}
