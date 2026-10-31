public import Foundation
import GRDB

/// One uninterrupted stretch of the same thing being in front of the user.
public struct ActivityStretch: Hashable, Sendable {
  public let anchor: Anchor
  public let start: Date
  public let end: Date

  public init(anchor: Anchor, start: Date, end: Date) {
    self.anchor = anchor
    self.start = start
    self.end = end
  }

  public var duration: TimeInterval { end.timeIntervalSince(start) }
}

extension Source {
  /// The app behind this Source, used for exclusions.
  public var bundleID: String {
    switch self {
    case .safari: "com.apple.Safari"
    case .chrome: "com.google.Chrome"
    case .firefox: "org.mozilla.firefox"
    case .app(let bundleID): bundleID
    }
  }
}

struct ActivityRecord: Codable, FetchableRecord, MutablePersistableRecord {
  static let databaseTableName = "activity"

  var id: Int64?
  var source: String
  var identifier: String
  var link: String
  var title: String
  var start: Double
  var lastSeen: Double
  var closed: Bool

  mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }

  var anchor: Anchor {
    Anchor(source: Source(stored: source), identifier: identifier, link: link, title: title)
  }
}

extension Core {
  /// Longest silence between two observations that still counts as one stretch.
  /// Anything longer (sleep, a crash) ends the stretch where it was last seen.
  static let activityMaxGap: TimeInterval = 120

  static let defaultExcludedApps = ["com.1password.1password", "com.agilebits.onepassword7"]

  private enum ActivitySetting {
    static let paused = "activityPaused"
    static let excludedApps = "activityExcludedApps"
    static let retentionDays = "activityRetentionDays"
  }

  // MARK: Recording

  /// Records what's in front of the user right now. Call on every app or window change and
  /// regularly in between. `nil` means nothing recordable is in front (e.g. a private window).
  public func recordActivity(_ anchor: Anchor?) throws {
    guard try !isActivityPaused() else { return }
    let excluded = Set(try excludedApps())
    let recordable = anchor.flatMap { excluded.contains($0.source.bundleID) ? nil : $0 }
    let now = time.now.timeIntervalSince1970

    try database.writer.write { db in
      let current = try Self.openStretch(db)
      if var current, let recordable, current.identifier == recordable.identifier,
        now - current.lastSeen <= Self.activityMaxGap
      {
        current.lastSeen = now
        current.title = recordable.title
        try current.update(db)
        return
      }
      if var current {
        if now - current.lastSeen <= Self.activityMaxGap { current.lastSeen = now }
        current.closed = true
        try current.update(db)
      }
      guard let recordable else { return }
      var stretch = ActivityRecord(
        id: nil,
        source: recordable.source.stored,
        identifier: recordable.identifier,
        link: recordable.link,
        title: recordable.title,
        start: now,
        lastSeen: now,
        closed: false
      )
      try stretch.insert(db)
    }
  }

  /// Ends the current stretch at `end`, e.g. when the user went idle at that time or locked the screen.
  public func stopActivity(at end: Date) throws {
    try database.writer.write { db in
      guard var current = try Self.openStretch(db) else { return }
      current.lastSeen = max(current.start, end.timeIntervalSince1970)
      current.closed = true
      try current.update(db)
    }
  }

  public func setActivityPaused(_ paused: Bool) throws {
    if paused { try recordActivity(nil) }
    try database.setSetting(ActivitySetting.paused, to: paused ? "1" : nil)
  }

  public func isActivityPaused() throws -> Bool {
    try database.setting(ActivitySetting.paused) == "1"
  }

  /// Bundle identifiers of apps that are never recorded.
  public func excludedApps() throws -> [String] {
    guard let stored = try database.setting(ActivitySetting.excludedApps) else { return Self.defaultExcludedApps }
    return stored.split(separator: "\n").map(String.init)
  }

  public func setExcludedApps(_ bundleIDs: [String]) throws {
    let cleaned = bundleIDs.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    try database.setSetting(ActivitySetting.excludedApps, to: cleaned.joined(separator: "\n"))
  }

  public func activityRetentionDays() throws -> Int {
    try database.setting(ActivitySetting.retentionDays).flatMap(Int.init) ?? 90
  }

  public func setActivityRetentionDays(_ days: Int) throws {
    try database.setSetting(ActivitySetting.retentionDays, to: String(max(1, days)))
  }

  /// Deletes Activity older than the retention period.
  public func pruneActivity() throws {
    let cutoff = time.now.timeIntervalSince1970 - Double(try activityRetentionDays()) * 86_400
    try database.writer.write { db in
      _ = try ActivityRecord.filter(Column("lastSeen") < cutoff).deleteAll(db)
    }
  }

  // MARK: Queries

  /// Activity between `from` and `to`, oldest first, clipped to the range.
  public func activity(from: Date, to: Date) throws -> [ActivityStretch] {
    let lower = from.timeIntervalSince1970
    let upper = to.timeIntervalSince1970
    return try database.writer.read { db in
      try ActivityRecord
        .filter(Column("start") <= upper && Column("lastSeen") >= lower)
        .order(Column("start"), Column("id"))
        .fetchAll(db)
        .map { record in
          ActivityStretch(
            anchor: record.anchor,
            start: Date(timeIntervalSince1970: max(record.start, lower)),
            end: Date(timeIntervalSince1970: min(record.lastSeen, upper))
          )
        }
    }
  }

  private static func openStretch(_ db: Database) throws -> ActivityRecord? {
    try ActivityRecord.filter(Column("closed") == false).order(Column("start").desc).fetchOne(db)
  }
}
