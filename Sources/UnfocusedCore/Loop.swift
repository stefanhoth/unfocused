public import Foundation

/// Anything the user started or committed to that isn't closed yet (see GLOSSARY.md).
public struct Loop: Identifiable, Hashable, Sendable {
  public let id: UUID
  public var title: String
  public var state: LoopState
  public let capturedAt: Date
  /// How to get back into this Loop, written when the user last left it.
  public var whereILeftOff: String?

  public init(id: UUID, title: String, state: LoopState, capturedAt: Date, whereILeftOff: String? = nil) {
    self.id = id
    self.title = title
    self.state = state
    self.capturedAt = capturedAt
    self.whereILeftOff = whereILeftOff
  }
}

/// One stretch of time during which a Loop was the Focused Loop.
public struct FocusSession: Hashable, Sendable {
  public let loopID: UUID
  public let start: Date
  /// `nil` while the Focus is still going on.
  public let end: Date?

  public init(loopID: UUID, start: Date, end: Date?) {
    self.loopID = loopID
    self.start = start
    self.end = end
  }

  /// Length of a finished Focus; zero while it's still going on.
  public var duration: TimeInterval { (end ?? start).timeIntervalSince(start) }
}

public enum LoopState: String, Sendable, CaseIterable {
  case open
  case closed
  case dropped
}

public enum CoreError: Error, Equatable {
  case emptyTitle
  case loopNotFound
  /// The Loop must be Open for this, e.g. to be Focused.
  case loopNotOpen
  /// The Loop's current state doesn't allow this change (e.g. reopening an Open Loop).
  case invalidStateChange
}

/// Something that happened to a Loop, as shown in its history.
public enum LoopChange: String, Sendable, CaseIterable {
  case captured
  case closed
  case dropped
  case reopened
}

public struct LoopEvent: Hashable, Sendable {
  public let change: LoopChange
  public let at: Date

  public init(change: LoopChange, at: Date) {
    self.change = change
    self.at = at
  }
}
