import Foundation
import Testing
import UnfocusedCore

@Suite("Capture")
struct CaptureTests {
  @Test("capturing creates an Open Loop with the trimmed title")
  func capturesOpenLoop() throws {
    let (core, time) = try makeCore()

    let loop = try core.capture(title: "  Reply to Anna about the contract \n")

    #expect(loop.title == "Reply to Anna about the contract")
    #expect(loop.state == .open)
    #expect(loop.capturedAt == time.now)
    #expect(try core.openLoops() == [loop])
  }

  @Test("an empty title is rejected")
  func rejectsEmptyTitle() throws {
    let (core, _) = try makeCore()

    #expect(throws: CoreError.emptyTitle) { try core.capture(title: "   ") }
    #expect(try core.openLoops().isEmpty)
  }

  @Test("Open Loops are listed newest first")
  func newestFirst() throws {
    let (core, time) = try makeCore()
    let older = try core.capture(title: "Older")
    time.advance(by: .minutes(5))
    let newer = try core.capture(title: "Newer")

    #expect(try core.openLoops() == [newer, older])
  }

  @Test("captured Loops survive reopening the database file")
  func persists() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("unfocused.sqlite")
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let time = TestTime()

    let loop = try Core(database: .open(at: url), time: time).capture(title: "Survives restarts")
    let reopened = try Core(database: .open(at: url), time: time)

    #expect(try reopened.openLoops() == [loop])
  }
}
