import AppKit
import Observation
import UnfocusedCore
import UnfocusedReasoner

/// App-wide state for the UI. Every change goes through Core; the model only mirrors it.
@MainActor
@Observable
final class AppModel {
  private(set) var openLoops: [Loop] = []
  private(set) var focusedLoop: Loop?
  private(set) var people: [Person] = []
  /// How each Open Loop is aging toward a Loose End, by Loop.
  private(set) var aging: [Loop.ID: LoopAging] = [:]
  /// Loose Ends, most aged first.
  private(set) var looseEnds: [LoopAging] = []
  private(set) var activityPaused = false
  private(set) var hotKey: HotKeyChoice = .default
  /// Why the chosen hotkey can't be used, shown in Settings.
  private(set) var hotKeyProblem: String?
  private(set) var lastError: String?
  /// Settings are read from Core on demand; this goes up on every change so views showing a
  /// setting redraw (they observe this, not the database).
  private var settingsRevision = 0

  @ObservationIgnored let core: Core
  @ObservationIgnored let log: Log
  @ObservationIgnored let reasoner = FoundationModelsReasoner()

  init(core: Core, log: Log) {
    self.core = core
    self.log = log
    refresh()
  }

  /// Called whenever the Focused Loop changes, however it happened: (now, before).
  @ObservationIgnored var onFocusChange: ((Loop?, Loop?) -> Void)?

  func refresh() {
    do {
      openLoops = try core.openLoops()
      let before = focusedLoop
      focusedLoop = try core.focusedLoop()
      if before?.id != focusedLoop?.id { onFocusChange?(focusedLoop, before) }
      people = try core.people()
      let allAging = try core.agingOfOpenLoops()
      aging = Dictionary(allAging.map { ($0.loop.id, $0) }) { first, _ in first }
      looseEnds = allAging.filter(\.isLooseEnd)
      activityPaused = try core.isActivityPaused()
    } catch {
      report(error, while: "loading Loops")
    }
  }

  func search(_ query: String) -> [Loop] {
    (try? core.searchOpenLoops(query)) ?? []
  }

  /// Returns the new Loop, or `nil` if nothing was captured.
  @discardableResult
  func capture(title: String, anchor: Anchor? = nil, directions: [String: Direction] = [:]) -> Loop? {
    do {
      let loop = try core.capture(title: title, anchor: anchor, directions: directions)
      log.info("Captured Loop \(loop.id)")
      refresh()
      return loop
    } catch CoreError.emptyTitle {
      return nil
    } catch {
      report(error, while: "capturing")
      return nil
    }
  }

  /// Focuses `loop` and opens its Anchors. Returns the Loop the user just left, so they can say where
  /// they left off. Pass `openAnchors: false` when the user is already where the Loop lives.
  @discardableResult
  func focus(_ loop: Loop, openAnchors: Bool = true) -> Loop? {
    // Read the current Focus from Core: the cached one may be stale (e.g. after an interruption).
    let previous = (try? core.focusedLoop()) ?? nil
    do {
      try core.focus(loop.id)
      log.info("Focused Loop \(loop.id)")
      if openAnchors, previous?.id != loop.id { anchors(of: loop).forEach(AnchorOpener.open) }
    } catch {
      report(error, while: "focusing")
    }
    refresh()
    return previous?.id == loop.id ? nil : previous
  }

  /// Ends the current Focus. Returns the Loop the user just left.
  @discardableResult
  func unfocus() -> Loop? {
    let previous = (try? core.focusedLoop()) ?? nil
    do {
      try core.unfocus()
      log.info("Unfocused")
    } catch {
      report(error, while: "unfocusing")
    }
    refresh()
    return previous
  }

  /// Closes `loop`. Returns it when it was the Focused Loop, so the user can say where they left off.
  @discardableResult
  func close(_ loop: Loop) -> Loop? {
    changeState(of: loop, "closing") { try core.close(loop.id) }
  }

  /// Lets go of `loop`. Returns it when it was the Focused Loop.
  @discardableResult
  func letGo(_ loop: Loop) -> Loop? {
    changeState(of: loop, "letting go") { try core.letGo(loop.id) }
  }

  func reopen(_ loop: Loop) {
    _ = changeState(of: loop, "reopening") { try core.reopen(loop.id) }
  }

  /// Not now on the switch banner: no more suggestions until the Focus changes.
  func notNowSilentSwitch() {
    perform("saving Not now") { try core.notNowSilentSwitch() }
  }

  // MARK: Interrupted Focus

  /// The Focus that sleep, idle or a screen lock stopped, if the user hasn't answered yet.
  func interruptedFocus() -> FocusInterruption? {
    try? core.interruptedFocus()
  }

  func interruptFocus(at time: Date, because reason: FocusInterruptionReason) {
    perform("pausing Focus") { try core.interruptFocus(at: time, because: reason) }
  }

  /// Continue: Focus the interrupted Loop again.
  func continueInterruptedFocus() {
    perform("continuing Focus") { try core.continueInterruptedFocus() }
  }

  /// Unfocus after an interruption: forget it and stay unfocused.
  func dismissInterruptedFocus() {
    perform("unfocusing") { try core.dismissInterruptedFocus() }
  }

  /// Ends a Focus left running while the app was quit or the Mac was off.
  func endStaleFocus() {
    perform("checking Focus") { try core.endStaleFocus() }
  }

  // MARK: Capture nudges

  /// Open Loops that look related to what's being typed, strongest first.
  func relatedLoops(toCapture text: String, anchor: Anchor?) -> [RelatedLoop] {
    guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
    return (try? core.relatedLoops(toCapture: text, anchor: anchor)) ?? []
  }

  /// Related Loops including matches by meaning from the on-device model, if it's available.
  func relatedLoopsByMeaning(toCapture text: String, anchor: Anchor?) async -> [RelatedLoop] {
    (try? await core.relatedLoops(toCapture: text, anchor: anchor, reasoner: reasoner)) ?? []
  }

  /// A Capture title for `anchor`: the on-device model's suggestion, or the Anchor's title.
  func captureTitle(for anchor: Anchor) async -> String {
    await core.captureTitle(for: anchor, reasoner: reasoner)
  }

  /// Whether the on-device model can be used (Apple Intelligence on and supported).
  var reasonerAvailable: Bool { reasoner.isAvailable }

  /// "N Loose Ends are older than this idea", when there are enough to mention.
  func looseEndsOlderThanNewIdea() -> Int? {
    try? core.looseEndsOlderThanNewIdea()
  }

  /// "Add to this Loop instead": adds the context as an Anchor and the mentioned People to an
  /// existing Loop rather than capturing a new one.
  func add(to loop: Loop, anchor: Anchor?, mentionsIn text: String, directions: [String: Direction]) {
    perform("adding to a Loop") {
      if let anchor { try core.addAnchor(anchor, to: loop.id) }
      for name in try core.mentionedNames(in: text) {
        let person = try core.addPerson(named: name, evenIfSimilar: true)
        let direction = directions.first { $0.key.lowercased() == name.lowercased() }?.value ?? .owed
        try core.involve(person.id, in: loop.id, as: direction)
      }
    }
  }

  /// A Tie-off over the current Loose Ends.
  func startTieOff() -> TieOff {
    (try? core.startTieOff()) ?? TieOff(looseEnds: [])
  }

  /// Active days without Engagement before a Loop is a Loose End.
  var looseEndThreshold: Int {
    get {
      _ = settingsRevision
      return (try? core.looseEndThreshold()) ?? 3
    }
    set {
      perform("saving the Loose End threshold") { try core.setLooseEndThreshold(newValue) }
      settingsRevision += 1
    }
  }

  /// Minutes without input that pause Focus.
  var focusIdleMinutes: Int {
    get {
      _ = settingsRevision
      return Int(((try? core.focusIdleThreshold()) ?? 1800) / 60)
    }
    set {
      perform("saving the idle time") { try core.setFocusIdleThreshold(TimeInterval(newValue) * 60) }
      settingsRevision += 1
    }
  }

  func loop(anchoredAt anchor: Anchor) -> Loop? {
    try? core.loop(anchoredAt: anchor)
  }

  func addAnchor(_ anchor: Anchor, to loop: Loop) {
    perform("adding an Anchor") { try core.addAnchor(anchor, to: loop.id) }
  }

  /// Opens Edit Loop for `loop`; wired up by the app delegate.
  @ObservationIgnored var editLoop: ((Loop) -> Void)?

  func loop(_ id: UUID) -> Loop? {
    _ = openLoops
    return try? core.loop(id)
  }

  func retitle(_ loop: Loop, to title: String) {
    perform("renaming the Loop") { try core.retitle(loop.id, to: title) }
  }

  func renameAnchor(_ anchor: Anchor, of loop: Loop, to title: String) {
    perform("renaming the Anchor") { try core.renameAnchor(anchor, of: loop.id, to: title) }
  }

  func removeAnchor(_ anchor: Anchor, from loop: Loop) {
    perform("removing an Anchor") { try core.removeAnchor(anchor, from: loop.id) }
  }

  func anchors(of loop: Loop) -> [Anchor] {
    (try? core.anchors(of: loop.id)) ?? []
  }

  func loops(in state: LoopState) -> [Loop] {
    (try? core.loops(in: state)) ?? []
  }

  func history(for loop: Loop) -> [LoopEvent] {
    (try? core.history(for: loop.id)) ?? []
  }

  func focusSessions(for loop: Loop) -> [FocusSession] {
    (try? core.focusSessions(for: loop.id)) ?? []
  }

  private func changeState(of loop: Loop, _ action: String, _ change: () throws -> Void) -> Loop? {
    let wasFocused = ((try? core.focusedLoop()) ?? nil)?.id == loop.id
    do {
      try change()
      log.info("Finished \(action) Loop \(loop.id)")
    } catch {
      report(error, while: "\(action) a Loop")
    }
    refresh()
    return wasFocused ? loop : nil
  }

  func setWhereILeftOff(_ loop: Loop, to note: String) {
    do {
      try core.setWhereILeftOff(loop.id, to: note)
    } catch {
      report(error, while: "saving where you left off")
    }
    refresh()
  }

  // MARK: People

  func searchPeople(_ query: String) -> [Person] {
    (try? core.searchPeople(query)) ?? []
  }

  func mentionedNames(in text: String) -> [String] {
    (try? core.mentionedNames(in: text)) ?? []
  }

  func importPeople(_ text: String) -> PeopleImport? {
    defer { refresh() }
    do {
      let result = try core.importPeople(text)
      log.info("Imported \(result.added.count) People, \(result.nearMatches.count) near matches")
      return result
    } catch {
      report(error, while: "importing People")
      return nil
    }
  }

  /// The user decided a near-duplicate is a different Person.
  func keepAsNewPerson(_ name: String) {
    perform("adding a Person") { _ = try core.addPerson(named: name, evenIfSimilar: true) }
  }

  func rename(_ person: Person, to name: String) {
    perform("renaming a Person") { try core.rename(person.id, to: name) }
  }

  func delete(_ person: Person) {
    perform("deleting a Person") { try core.deletePerson(person.id) }
  }

  func merge(_ duplicate: Person, into person: Person) {
    perform("merging People") { try core.merge(duplicate.id, into: person.id) }
  }

  func involvements(of loop: Loop) -> [Involvement] {
    (try? core.people(of: loop.id)) ?? []
  }

  func loops(involving person: Person) -> [Loop] {
    (try? core.loops(involving: person.id)) ?? []
  }

  func involve(named name: String, in loop: Loop, as direction: Direction = .owed) {
    perform("adding a Person to a Loop") {
      let person = try core.addPerson(named: name, evenIfSimilar: true)
      try core.involve(person.id, in: loop.id, as: direction)
    }
  }

  func setDirection(_ direction: Direction, of person: Person, in loop: Loop) {
    perform("changing direction") { try core.involve(person.id, in: loop.id, as: direction) }
  }

  func remove(_ person: Person, from loop: Loop) {
    perform("removing a Person from a Loop") { try core.removePerson(person.id, from: loop.id) }
  }

  private func perform(_ action: String, _ work: () throws -> Void) {
    do {
      try work()
    } catch {
      report(error, while: action)
    }
    refresh()
  }

  // MARK: Activity

  func setActivityPaused(_ paused: Bool) {
    perform(paused ? "pausing Activity" : "resuming Activity") { try core.setActivityPaused(paused) }
  }

  /// Activity of one calendar day with the Loop each piece counts toward, oldest first.
  func attributedActivity(on day: Date) -> [AttributedStretch] {
    let start = Calendar.current.startOfDay(for: day)
    let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
    return (try? core.attributedActivity(from: start, to: end)) ?? []
  }

  /// Where and why time went to `loop` over the last 30 days, newest first, with consecutive
  /// pieces in the same place and for the same reason joined into one entry.
  func workLog(for loop: Loop) -> [AttributedStretch] {
    let now = Date()
    let log = (try? core.workLog(for: loop.id, from: now.addingTimeInterval(-30 * 86_400), to: now)) ?? []
    var joined: [AttributedStretch] = []
    for piece in log where piece.duration >= 1 {
      if let last = joined.last, last.anchor.identifier == piece.anchor.identifier, last.reason == piece.reason,
        last.focusedLoopID == piece.focusedLoopID,
        piece.start.timeIntervalSince(last.end) <= 120
      {
        joined[joined.count - 1] = AttributedStretch(
          anchor: piece.anchor,
          start: last.start,
          end: piece.end,
          loopID: piece.loopID,
          reason: piece.reason,
          focusedLoopID: piece.focusedLoopID
        )
      } else {
        joined.append(piece)
      }
    }
    return joined.reversed()
  }

  func lastEngagement(of loop: Loop) -> Date? {
    try? core.lastEngagement(of: loop.id)
  }

  /// Titles of all Loops by id, for labelling attributed Activity.
  func loopTitles() -> [UUID: String] {
    let all = LoopState.allCases.flatMap { (try? core.loops(in: $0)) ?? [] }
    return Dictionary(all.map { ($0.id, $0.title) }) { first, _ in first }
  }

  func recap(day: Date) -> Recap? { try? core.recap(day: day) }

  /// The on-device prose summary of a Recap, or `nil` without Apple Intelligence.
  func summary(of recap: Recap) async -> String? {
    await core.summary(of: recap, reasoner: reasoner)
  }

  func recap(weekOf date: Date) -> Recap? { try? core.recap(weekOf: date) }

  var excludedApps: [String] {
    get {
      _ = settingsRevision
      return (try? core.excludedApps()) ?? []
    }
    set {
      perform("saving excluded apps") { try core.setExcludedApps(newValue) }
      settingsRevision += 1
    }
  }

  var activityRetentionDays: Int {
    get {
      _ = settingsRevision
      return (try? core.activityRetentionDays()) ?? 90
    }
    set {
      perform("saving Activity retention") { try core.setActivityRetentionDays(newValue) }
      settingsRevision += 1
    }
  }

  // MARK: Hotkey

  /// Loads the saved hotkey and registers it. Returns `false` when it conflicts.
  @discardableResult
  func activateSavedHotKey() -> Bool {
    let saved = (try? core.database.setting(HotKeyChoice.settingKey)).flatMap(HotKeyChoice.init(rawValue:))
    return useHotKey(saved ?? .default)
  }

  @discardableResult
  func useHotKey(_ choice: HotKeyChoice) -> Bool {
    hotKey = choice
    try? core.database.setSetting(HotKeyChoice.settingKey, to: choice.rawValue)
    if let conflict = SystemShortcuts.conflict(for: choice) {
      HotKeyCenter.shared.unregister()
      hotKeyProblem = "\(choice.label) is already used by macOS (“\(conflict)”). Pick another key."
    } else if !HotKeyCenter.shared.register(choice) {
      hotKeyProblem = "\(choice.label) is already used by another app. Pick another key."
    } else {
      hotKeyProblem = nil
    }
    if let hotKeyProblem { log.info("Hotkey unavailable: \(hotKeyProblem)") }
    return hotKeyProblem == nil
  }

  private func report(_ error: any Error, while action: String) {
    lastError = "Something went wrong while \(action)."
    log.error("Failed while \(action): \(error)")
  }
}
