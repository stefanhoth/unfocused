public import Foundation

/// Where Core gets the current time from. Injected so tests control time.
public protocol TimeSource: Sendable {
  var now: Date { get }
}

/// The real wall clock.
public struct SystemTime: TimeSource {
  public init() {}
  public var now: Date { Date() }
}
