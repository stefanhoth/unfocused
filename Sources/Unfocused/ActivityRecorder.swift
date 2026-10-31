import AppKit
import CoreGraphics
import UnfocusedCore

/// Feeds what's in front of the user into Core's Activity record (never content or keystrokes).
@MainActor
final class ActivityRecorder {
  /// Without any input for this long, the user counts as idle.
  static let idleThreshold: TimeInterval = 5 * 60
  private static let sampleInterval: TimeInterval = 15

  private let core: Core
  private let log: Log
  private var timer: Timer?
  private var lastPrune = Date.distantPast
  private var observers: [(NotificationCenter, any NSObjectProtocol)] = []

  init(core: Core, log: Log) {
    self.core = core
    self.log = log
  }

  func start() {
    let workspace = NSWorkspace.shared.notificationCenter
    let distributed = DistributedNotificationCenter.default()
    observe(workspace, NSWorkspace.didActivateApplicationNotification) { $0.sample() }
    observe(workspace, NSWorkspace.willSleepNotification) { $0.stop(at: Date()) }
    observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.stop(at: Date()) }
    observe(workspace, NSWorkspace.didWakeNotification) { $0.sample() }
    observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.stop(at: Date()) }
    observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.sample() }

    timer = Timer.scheduledTimer(withTimeInterval: Self.sampleInterval, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.sample() }
    }
    sample()
  }

  /// Records the frontmost thing, or stops the current stretch when the user is idle.
  func sample() {
    pruneDaily()
    let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)
    if idle >= Self.idleThreshold {
      stop(at: Date().addingTimeInterval(-idle))
      return
    }
    let front = NSWorkspace.shared.frontmostApplication
    // unfocused's own panel and windows don't count; keep whatever was in front before.
    guard front?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
    let context = ContextReader.read(front, prompting: false)
    do {
      try core.recordActivity(context?.isPrivate == true ? nil : context?.anchor)
    } catch {
      log.error("Recording Activity failed: \(error)")
    }
  }

  private func stop(at time: Date) {
    do {
      try core.stopActivity(at: time)
    } catch {
      log.error("Stopping Activity failed: \(error)")
    }
  }

  private func pruneDaily() {
    guard Date().timeIntervalSince(lastPrune) > 86_400 else { return }
    lastPrune = Date()
    do {
      try core.pruneActivity()
    } catch {
      log.error("Pruning Activity failed: \(error)")
    }
  }

  private func observe(
    _ center: NotificationCenter,
    _ name: Notification.Name,
    _ action: @escaping @MainActor (ActivityRecorder) -> Void
  ) {
    let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        action(self)
      }
    }
    observers.append((center, token))
  }
}
