public import Foundation
import GRDB

/// Why a Focus stopped without the user ending it.
public enum FocusInterruptionReason: String, Sendable, CaseIterable {
  /// The Mac slept or shut down: the Focus ended.
  case sleep
  /// The user was idle or locked the screen: the Focus paused.
  case idle
}

/// A Focus that stopped on its own, waiting for the user to choose Continue, Close, Let go or Unfocus.
public struct FocusInterruption: Hashable, Sendable {
  public let loop: Loop
  public let reason: FocusInterruptionReason

  public init(loop: Loop, reason: FocusInterruptionReason) {
    self.loop = loop
    self.reason = reason
  }
}

extension Core {
  private enum InterruptionSetting {
    static let loop = "interruptedFocusLoop"
    static let reason = "interruptedFocusReason"
    static let idleThreshold = "focusIdleThresholdSeconds"
  }

  /// Ends the current Focus at `time` (when the user went idle, locked the screen or the Mac slept)
  /// and remembers the Loop so the user can be asked about it on return. Paused time isn't
  /// attributed, because the Focus has ended. Without a Focus, nothing happens.
  public func interruptFocus(at time: Date, because reason: FocusInterruptionReason) throws {
    try database.writer.write { db in
      guard let current = try Self.openFocus(db) else { return }
      try Self.end(current, at: max(current.start, time.timeIntervalSince1970), db)
      try Self.store(InterruptionSetting.loop, current.loopId, db)
      try Self.store(InterruptionSetting.reason, reason.rawValue, db)
    }
  }

  /// The interrupted Focus to ask about, if the user hasn't answered yet and the Loop is still Open.
  public func interruptedFocus() throws -> FocusInterruption? {
    try database.writer.read { db in
      guard
        let loopID = try Self.stored(InterruptionSetting.loop, db),
        let reason = try Self.stored(InterruptionSetting.reason, db).flatMap(FocusInterruptionReason.init),
        let loop = try LoopRecord.fetchOne(db, key: loopID)?.loop,
        loop.state == .open
      else { return nil }
      return FocusInterruption(loop: loop, reason: reason)
    }
  }

  /// Continue: Focuses the interrupted Loop again, starting now.
  public func continueInterruptedFocus() throws {
    guard let interruption = try interruptedFocus() else { return }
    try focus(interruption.loop.id)
  }

  /// Forgets the interrupted Focus without changing anything else.
  public func dismissInterruptedFocus() throws {
    try database.writer.write { db in try Self.clearInterruption(db) }
  }

  /// Ends a Focus that was left running while the app wasn't watching (quit, crash, shutdown):
  /// if nothing was seen for longer than the idle threshold, the Focus ends at the last Activity
  /// seen during it, as if the Mac had slept then.
  public func endStaleFocus() throws {
    let now = time.now.timeIntervalSince1970
    let threshold = try focusIdleThreshold()
    try database.writer.write { db in
      guard let current = try Self.openFocus(db) else { return }
      let seen = try Double.fetchOne(
        db,
        sql: "SELECT MAX(lastSeen) FROM activity WHERE lastSeen >= ?",
        arguments: [current.start]
      )
      let lastSign = seen ?? current.start
      guard now - lastSign > threshold else { return }
      try Self.end(current, at: lastSign, db)
      try Self.store(InterruptionSetting.loop, current.loopId, db)
      try Self.store(InterruptionSetting.reason, FocusInterruptionReason.sleep.rawValue, db)
    }
  }

  /// How long without input pauses Focus. Defaults to 30 minutes; at least one minute.
  public func focusIdleThreshold() throws -> TimeInterval {
    try database.setting(InterruptionSetting.idleThreshold).flatMap(TimeInterval.init) ?? 30 * 60
  }

  public func setFocusIdleThreshold(_ threshold: TimeInterval) throws {
    try database.setSetting(InterruptionSetting.idleThreshold, to: String(max(60, threshold)))
  }

  // MARK: Helpers

  static func clearInterruption(_ db: Database) throws {
    try db.execute(
      sql: "DELETE FROM setting WHERE key IN (?, ?)",
      arguments: [InterruptionSetting.loop, InterruptionSetting.reason]
    )
  }

  /// Clears the interrupted Focus only if it is about `loopID`.
  static func clearInterruption(of loopID: String, _ db: Database) throws {
    guard try stored(InterruptionSetting.loop, db) == loopID else { return }
    try clearInterruption(db)
  }

  private static func store(_ key: String, _ value: String, _ db: Database) throws {
    try db.execute(
      sql: "INSERT INTO setting (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
      arguments: [key, value]
    )
  }

  private static func stored(_ key: String, _ db: Database) throws -> String? {
    try String.fetchOne(db, sql: "SELECT value FROM setting WHERE key = ?", arguments: [key])
  }
}
