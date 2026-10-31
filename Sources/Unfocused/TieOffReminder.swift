import AppKit
import UnfocusedCore
@preconcurrency import UserNotifications

/// The optional daily Tie-off prompt: unfocused's only notification. It fires at the chosen time,
/// and only when there are Loose Ends.
@MainActor
final class TieOffReminder: NSObject, UNUserNotificationCenterDelegate {
  private enum Setting {
    static let enabled = "tieOffReminderEnabled"
    static let minuteOfDay = "tieOffReminderMinuteOfDay"
  }

  private let model: AppModel
  private let tieOff: TieOffController
  private var timer: Timer?

  /// Notifications need a bundled app; `swift run` has none.
  private var center: UNUserNotificationCenter? {
    Bundle.main.bundleIdentifier == nil ? nil : .current()
  }

  init(model: AppModel, tieOff: TieOffController) {
    self.model = model
    self.tieOff = tieOff
    super.init()
  }

  func start() {
    center?.delegate = self
    schedule()
  }

  var isEnabled: Bool {
    (try? model.core.database.setting(Setting.enabled)) == "1"
  }

  /// Minutes after midnight; defaults to 16:30.
  var minuteOfDay: Int {
    (try? model.core.database.setting(Setting.minuteOfDay)).flatMap { $0.flatMap(Int.init) } ?? 16 * 60 + 30
  }

  func setEnabled(_ enabled: Bool) {
    try? model.core.database.setSetting(Setting.enabled, to: enabled ? "1" : nil)
    if enabled { center?.requestAuthorization(options: [.alert, .sound]) { _, _ in } }
    schedule()
  }

  func setMinuteOfDay(_ minute: Int) {
    try? model.core.database.setSetting(Setting.minuteOfDay, to: String(minute))
    schedule()
  }

  private func schedule() {
    timer?.invalidate()
    guard isEnabled else { return }
    let calendar = Calendar.current
    let now = Date()
    let today = calendar.date(
      bySettingHour: minuteOfDay / 60,
      minute: minuteOfDay % 60,
      second: 0,
      of: now
    )
    guard let today else { return }
    let next = today > now ? today : calendar.date(byAdding: .day, value: 1, to: today) ?? today
    let timer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.fire()
        self?.schedule()
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  private func fire() {
    model.refresh()
    let count = model.looseEnds.count
    guard count > 0, let center else { return }
    let content = UNMutableNotificationContent()
    content.title = "Time for a Tie-off"
    content.body = "\(count) Loose End\(count == 1 ? "" : "s") to go through. It takes a minute."
    content.sound = .default
    center.add(UNNotificationRequest(identifier: "tie-off", content: content, trigger: nil))
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    await MainActor.run { tieOff.show() }
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .sound]
  }
}
