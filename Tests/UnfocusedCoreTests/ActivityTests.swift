import Foundation
import Testing
import UnfocusedCore

private func page(_ path: String) -> Anchor {
  Anchor(source: .safari, identifier: "example.com/\(path)", link: "https://example.com/\(path)", title: path)
}

@Suite("Activity recording")
struct ActivityTests {
  @Test("staying on the same thing extends one stretch of Activity")
  func extends() throws {
    let (core, time) = try makeCore()
    let start = time.now

    try core.recordActivity(page("a"))
    time.advance(by: 30)
    try core.recordActivity(page("a"))
    time.advance(by: 30)
    try core.recordActivity(page("a"))

    let stretches = try core.activity(from: start, to: time.now)
    #expect(stretches.count == 1)
    #expect(stretches.first?.duration == 60)
    #expect(stretches.first?.anchor.identifier == page("a").identifier)
  }

  @Test("switching to something else starts a new stretch")
  func switches() throws {
    let (core, time) = try makeCore()
    let start = time.now

    try core.recordActivity(page("a"))
    time.advance(by: 30)
    try core.recordActivity(page("b"))
    time.advance(by: 30)
    try core.recordActivity(page("b"))

    let stretches = try core.activity(from: start, to: time.now)
    #expect(stretches.map(\.anchor.title) == ["a", "b"])
    #expect(stretches.map(\.duration) == [30, 30])
  }

  @Test("a long silence (sleep, crash) ends the stretch where it was last seen")
  func gapEndsStretch() throws {
    let (core, time) = try makeCore()
    let start = time.now

    try core.recordActivity(page("a"))
    time.advance(by: 20)
    try core.recordActivity(page("a"))
    time.advance(by: .hours(2))
    try core.recordActivity(page("a"))

    let stretches = try core.activity(from: start, to: time.now)
    #expect(stretches.map(\.duration) == [20, 0])
  }

  @Test("stopping (idle, screen lock) ends the stretch at the given time")
  func stop() throws {
    let (core, time) = try makeCore()
    let start = time.now
    try core.recordActivity(page("a"))
    time.advance(by: .minutes(10))

    try core.stopActivity(at: start.addingTimeInterval(.minutes(4)))
    time.advance(by: .minutes(1))
    try core.recordActivity(page("a"))

    let stretches = try core.activity(from: start, to: time.now)
    #expect(stretches.map(\.duration) == [.minutes(4), 0])
  }

  @Test("nothing recordable in front (an excluded app, a private window) ends the stretch")
  func nothingRecordable() throws {
    let (core, time) = try makeCore()
    let start = time.now
    try core.recordActivity(page("a"))
    time.advance(by: 30)

    try core.recordActivity(nil)
    time.advance(by: 60)
    try core.recordActivity(nil)

    #expect(try core.activity(from: start, to: time.now).map(\.duration) == [30])
  }

  @Test("excluded apps are never recorded, and 1Password is excluded by default")
  func exclusions() throws {
    let (core, time) = try makeCore()
    let start = time.now
    let onePassword = Anchor.appWindow(bundleID: "com.1password.1password", appName: "1Password", windowTitle: "Vault")
    let notes = Anchor.appWindow(bundleID: "com.apple.Notes", appName: "Notes", windowTitle: nil)

    try core.recordActivity(onePassword)
    time.advance(by: 30)
    try core.setExcludedApps(["com.apple.Notes"])
    try core.recordActivity(notes)
    time.advance(by: 30)

    #expect(try core.activity(from: start, to: time.now).isEmpty)
    #expect(try core.excludedApps() == ["com.apple.Notes"])
  }

  @Test("while paused nothing is recorded")
  func pause() throws {
    let (core, time) = try makeCore()
    let start = time.now
    try core.recordActivity(page("a"))
    time.advance(by: 30)

    try core.setActivityPaused(true)
    time.advance(by: 30)
    try core.recordActivity(page("b"))
    time.advance(by: 30)
    #expect(try core.isActivityPaused())

    try core.setActivityPaused(false)
    try core.recordActivity(page("c"))
    time.advance(by: 30)
    try core.recordActivity(page("c"))

    #expect(try core.activity(from: start, to: time.now).map(\.anchor.title) == ["a", "c"])
  }

  @Test("Activity older than the retention period is deleted")
  func retention() throws {
    let (core, time) = try makeCore()
    let start = time.now
    try core.recordActivity(page("old"))
    time.advance(by: .days(91))
    try core.recordActivity(page("new"))

    try core.pruneActivity()

    #expect(try core.activityRetentionDays() == 90)
    #expect(try core.activity(from: start, to: time.now).map(\.anchor.title) == ["new"])
  }

  @Test("a range only returns the Activity inside it, clipped to its edges")
  func range() throws {
    let (core, time) = try makeCore()
    let start = time.now
    try core.recordActivity(page("a"))
    time.advance(by: 60)
    try core.recordActivity(page("a"))

    let middle = try core.activity(from: start.addingTimeInterval(20), to: start.addingTimeInterval(40))

    #expect(middle.map(\.duration) == [20])
  }
}
