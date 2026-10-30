public import Foundation

/// Anything the user started or committed to that isn't closed yet (see GLOSSARY.md).
public struct Loop: Identifiable, Hashable, Sendable {
  public let id: UUID
  public var title: String
  public var state: LoopState
  public let capturedAt: Date

  public init(id: UUID, title: String, state: LoopState, capturedAt: Date) {
    self.id = id
    self.title = title
    self.state = state
    self.capturedAt = capturedAt
  }
}

public enum LoopState: String, Sendable, CaseIterable {
  case open
  case closed
  case dropped
}

public enum CoreError: Error, Equatable {
  case emptyTitle
  case loopNotFound
}
