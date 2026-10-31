public import Foundation
import GRDB

extension Core {
  /// How long the user must stay in another Loop's Anchor before unfocused suggests switching.
  public static let silentSwitchDwell: TimeInterval = 3 * 60

  static let silentSwitchNotNowSetting = "silentSwitchNotNow"

  /// The Open Loop the user seems to be working on without having Focused it: they've been in one
  /// of its Anchors without a break for `silentSwitchDwell`, and it isn't the Focused Loop.
  /// `nil` after Not now, until the Focus changes.
  public func silentSwitchSuggestion() throws -> Loop? {
    let now = time.now.timeIntervalSince1970
    return try database.writer.read { db in
      guard
        try String.fetchOne(
          db,
          sql: "SELECT value FROM setting WHERE key = ?",
          arguments: [Self.silentSwitchNotNowSetting]
        ) == nil
      else { return nil }
      guard
        let current = try ActivityRecord.filter(Column("closed") == false).order(Column("start").desc).fetchOne(db),
        now - current.lastSeen <= Self.activityMaxGap,
        current.lastSeen - current.start >= Self.silentSwitchDwell
      else { return nil }
      let focusedID = try Self.openFocus(db)?.loopId
      let owners =
        try LoopRecord
        .filter(sql: "id IN (SELECT loopId FROM anchor WHERE identifier = ?)", arguments: [current.identifier])
        .filter(Column("state") == LoopState.open.rawValue)
        .order(Column("stateChangedAt").desc)
        .fetchAll(db)
      guard !owners.contains(where: { $0.id == focusedID }) else { return nil }
      return owners.first?.loop
    }
  }

  /// Not now: no more switch suggestions until the Focus changes.
  public func notNowSilentSwitch() throws {
    try database.setSetting(Self.silentSwitchNotNowSetting, to: "1")
  }

  static func clearSilentSwitchNotNow(_ db: Database) throws {
    try db.execute(sql: "DELETE FROM setting WHERE key = ?", arguments: [silentSwitchNotNowSetting])
  }
}
