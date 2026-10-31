import Foundation
import Synchronization
import UnfocusedCore

/// A clock the test controls. Starts at a fixed date and only moves when told to.
final class TestTime: TimeSource, Sendable {
  private let current: Mutex<Date>

  init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
    current = Mutex(start)
  }

  var now: Date { current.withLock { $0 } }

  func advance(by interval: TimeInterval) {
    current.withLock { $0 = $0.addingTimeInterval(interval) }
  }
}

extension TimeInterval {
  static func minutes(_ value: Double) -> TimeInterval { value * 60 }
  static func hours(_ value: Double) -> TimeInterval { value * 3600 }
  static func days(_ value: Double) -> TimeInterval { value * 86_400 }
}

/// A Gregorian calendar in UTC, so day boundaries don't depend on where tests run.
let utcCalendar: Calendar = {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
  return calendar
}()

/// A fresh Core on an in-memory database with a controllable clock and a UTC calendar.
/// The clock starts at 08:00 UTC.
func makeCore(time: TestTime = TestTime()) throws -> (Core, TestTime) {
  (try Core(database: .inMemory(), time: time, calendar: utcCalendar), time)
}
