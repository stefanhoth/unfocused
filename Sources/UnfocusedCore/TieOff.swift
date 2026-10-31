import Foundation

/// One pass through the Loose Ends, one at a time (see GLOSSARY.md). Resolving a Loop (Focus,
/// Close, Drop) goes through Core as usual; the Tie-off only tracks where the user is.
public struct TieOff: Hashable, Sendable {
  /// The Loose Ends this Tie-off started with, most aged first.
  public let looseEnds: [LoopAging]
  /// Loose Ends set aside with Not now. They stay Loose Ends and come up again next time.
  public private(set) var setAside: [LoopAging] = []
  private var position = 0

  public init(looseEnds: [LoopAging]) {
    self.looseEnds = looseEnds
  }

  public var total: Int { looseEnds.count }

  /// The Loose End to decide on now; `nil` when done.
  public var current: LoopAging? { looseEnds.indices.contains(position) ? looseEnds[position] : nil }

  /// How many have been decided on so far.
  public var done: Int { min(position, total) }

  public var isFinished: Bool { current == nil }

  /// Moves on after the current Loop was resolved.
  public mutating func next() {
    position += 1
  }

  /// Not now: moves on without touching the Loop. This isn't Engagement.
  public mutating func notNow() {
    if let current { setAside.append(current) }
    next()
  }
}

extension Core {
  /// Starts a Tie-off over the current Loose Ends.
  public func startTieOff() throws -> TieOff {
    TieOff(looseEnds: try looseEnds())
  }
}
