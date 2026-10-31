import AppKit
import CoreGraphics
import UnfocusedCore
import UnfocusedReasoner

/// Feeds what's in front of the user into Core's Activity record (never content or keystrokes).
@MainActor
final class ActivityRecorder {
  /// Without any input for this long, the user counts as idle.
  static let idleThreshold: TimeInterval = 5 * 60
  private static let sampleInterval: TimeInterval = 15

  private let core: Core
  private let log: Log
  /// Called when the user is back after a Focus was interrupted, to ask what to do with it.
  var onReturn: ((FocusInterruption) -> Void)?
  /// Called after a Focus was interrupted (sleep, idle, lock), so the UI can catch up.
  var onFocusInterrupted: (() -> Void)?
  /// Called after every sample with the Loop the user seems to be on without Focusing it, or `nil`.
  var onSwitchSuggestion: ((Loop?) -> Void)?
  /// The interruption the user was already asked about, so they're asked once.
  private var askedAbout: FocusInterruption?
  private var timer: Timer?
  private var lastPrune = Date.distantPast
  private var lastJudgement = Date.distantPast
  private let reasoner = FoundationModelsReasoner()
  private var observers: [(NotificationCenter, any NSObjectProtocol)] = []

  init(core: Core, log: Log) {
    self.core = core
    self.log = log
  }

  func start() {
    let workspace = NSWorkspace.shared.notificationCenter
    let distributed = DistributedNotificationCenter.default()
    observe(workspace, NSWorkspace.didActivateApplicationNotification) { $0.sample() }
    observe(workspace, NSWorkspace.willSleepNotification) { $0.away(at: Date(), .sleep) }
    observe(workspace, NSWorkspace.willPowerOffNotification) { $0.away(at: Date(), .sleep) }
    observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.stop(at: Date()) }
    observe(workspace, NSWorkspace.didWakeNotification) { $0.sample() }
    observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.away(at: Date(), .idle) }
    observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.sample() }

    timer = Timer.scheduledTimer(withTimeInterval: Self.sampleInterval, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.sample() }
    }
    sample()
  }

  /// Records the frontmost thing, or stops the current stretch when the user is idle.
  func sample() {
    pruneDaily()
    judgeRecent()
    let idle = Self.secondsSinceLastInput
    let idleSince = Date().addingTimeInterval(-idle)
    if idle >= ((try? core.focusIdleThreshold()) ?? 1800) {
      interrupt(at: idleSince, .idle)
    }
    if idle >= Self.idleThreshold {
      stop(at: idleSince)
      onSwitchSuggestion?(nil)
      return
    }
    askIfBack()
    let front = NSWorkspace.shared.frontmostApplication
    // unfocused's own panel and windows don't count; keep whatever was in front before.
    guard front?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
    let context = ContextReader.read(front, prompting: false)
    do {
      try core.recordActivity(context?.isPrivate == true ? nil : context?.anchor)
      onSwitchSuggestion?(try core.silentSwitchSuggestion())
    } catch {
      log.error("Recording Activity failed: \(error)")
    }
  }

  /// The user left: stop Activity and interrupt Focus.
  private func away(at time: Date, _ reason: FocusInterruptionReason) {
    stop(at: time)
    interrupt(at: time, reason)
  }

  private func interrupt(at time: Date, _ reason: FocusInterruptionReason) {
    do {
      let wasFocused = try core.focusedLoop() != nil
      try core.interruptFocus(at: time, because: reason)
      if wasFocused { onFocusInterrupted?() }
    } catch {
      log.error("Interrupting Focus failed: \(error)")
    }
  }

  /// Asks about an interrupted Focus once the user is active again.
  private func askIfBack() {
    guard let interruption = try? core.interruptedFocus(), interruption != askedAbout else { return }
    askedAbout = interruption
    onReturn?(interruption)
  }

  /// Seconds since the last keyboard, mouse or trackpad input. Asks for "any input type"
  /// (`kCGAnyInputEventType`, all bits set): the `.null` event type never occurs, so asking for it
  /// returns the time since boot and made every check look idle.
  static var secondsSinceLastInput: TimeInterval {
    guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
    return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
  }

  private func stop(at time: Date) {
    do {
      try core.stopActivity(at: time)
    } catch {
      log.error("Stopping Activity failed: \(error)")
    }
  }

  /// Every few minutes, lets the on-device model judge today's Focus time outside the Loop's Anchors.
  private func judgeRecent() {
    guard reasoner.isAvailable, Date().timeIntervalSince(lastJudgement) > 5 * 60 else { return }
    lastJudgement = Date()
    let core = core
    let reasoner = reasoner
    let log = log
    Task.detached(priority: .utility) {
      let now = Date()
      do {
        try await core.judgeFocusActivity(from: Calendar.current.startOfDay(for: now), to: now, with: reasoner)
      } catch {
        log.error("Judging Focus time failed: \(error)")
      }
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
