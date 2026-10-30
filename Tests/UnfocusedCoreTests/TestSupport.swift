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

/// A fresh Core on an in-memory database with a controllable clock.
func makeCore(time: TestTime = TestTime()) throws -> (Core, TestTime) {
  (try Core(database: .inMemory(), time: time), time)
}
