public import Foundation

/// Why an Open Loop looks related to what the user is about to capture.
public enum RelatedReason: Hashable, Sendable {
  /// It involves a Person mentioned in the new title.
  case samePerson(String)
  /// Its title shares meaningful words with the new title.
  case similarTitle
  /// One of its Anchors lives in the same place (website or app) as the current context.
  case sameSource
  /// The Reasoner judged it to be about the same thing.
  case similarMeaning
}

public struct RelatedLoop: Hashable, Sendable {
  public let loop: Loop
  /// Strongest first.
  public let reasons: [RelatedReason]
  public let score: Double

  public init(loop: Loop, reasons: [RelatedReason], score: Double) {
    self.loop = loop
    self.reasons = reasons
    self.score = score
  }
}

extension Core {
  /// How many Loose Ends make the panel mention them while capturing.
  static let looseEndNudgeMinimum = 3

  /// Open Loops that look related to a Loop about to be captured, strongest first, at most 3:
  /// shared People, similar titles, then Anchors in the same place.
  public func relatedLoops(toCapture text: String, anchor: Anchor?, meaningMatches: Set<UUID> = []) throws
    -> [RelatedLoop]
  {
    let people = try self.people()
    let parsed = Mentions.parse(text, knownNames: people.map(\.name))
    let mentioned = Set(parsed.names.map(NameMatching.key))
    let nameWords = Set(people.flatMap { TitleWords.words(in: $0.name) })
    let typedWords = TitleWords.words(in: parsed.title).subtracting(nameWords)
    let place = anchor?.place

    let candidates = try openLoops()
    return try candidates.compactMap { loop -> RelatedLoop? in
      var reasons: [RelatedReason] = []
      var score = 0.0
      for involvement in try self.people(of: loop.id)
      where mentioned.contains(NameMatching.key(involvement.person.name)) {
        reasons.append(.samePerson(involvement.person.name))
        score += 3
      }
      let similarity = TitleWords.similarity(typedWords, TitleWords.words(in: loop.title).subtracting(nameWords))
      if similarity >= 0.3 {
        reasons.append(.similarTitle)
        score += 4 * similarity
      }
      if meaningMatches.contains(loop.id), !reasons.contains(.similarTitle) {
        reasons.append(.similarMeaning)
        score += 2.5
      }
      if let place, try anchors(of: loop.id).contains(where: { $0.place == place }) {
        reasons.append(.sameSource)
        score += 1
      }
      return reasons.isEmpty ? nil : RelatedLoop(loop: loop, reasons: reasons, score: score)
    }
    .sorted { lhs, rhs in lhs.score != rhs.score ? lhs.score > rhs.score : lhs.loop.capturedAt > rhs.loop.capturedAt }
    .prefix(3)
    .map { $0 }
  }

  /// The number of Loose Ends to mention while capturing ("3 Loose Ends are older than this idea"),
  /// or `nil` when there are too few to bring up. Capture is never blocked.
  public func looseEndsOlderThanNewIdea() throws -> Int? {
    let count = try looseEnds().count
    return count >= Self.looseEndNudgeMinimum ? count : nil
  }
}

/// Meaningful words of a title, for lexical similarity.
enum TitleWords {
  private static let common: Set<String> = [
    "the", "and", "for", "with", "from", "about", "this", "that", "into", "onto", "our", "your", "their",
    "are", "was", "were", "has", "have", "had", "not", "but", "all", "any", "can", "will", "just",
    "der", "die", "das", "und", "mit", "für", "von", "den", "dem", "des", "ein", "eine", "auf", "aus",
  ]

  static func words(in text: String) -> Set<String> {
    let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    return Set(
      folded.split { !$0.isLetter && !$0.isNumber }
        .map(String.init)
        .filter { $0.count >= 3 && !common.contains($0) }
    )
  }

  /// Shared words over all words (Jaccard); 0 when either side is empty.
  static func similarity(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
    guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
    return Double(lhs.intersection(rhs).count) / Double(lhs.union(rhs).count)
  }
}
