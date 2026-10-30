import Foundation

/// Scores how well a typed query matches a Loop title.
///
/// Every whitespace-separated word of the query must match, ignoring case and
/// accents. A word scores highest as a prefix of a title word, then as a
/// substring, then as letters in order ("qbr" → "Quarterly budget review").
/// Returns `nil` when any word doesn't match.
enum FuzzyMatch {
  static func score(query: String, in text: String) -> Int? {
    let words = normalize(query).split(whereSeparator: \.isWhitespace)
    guard !words.isEmpty else { return 0 }
    let haystack = normalize(text)
    let titleWords = haystack.split(whereSeparator: { !$0.isLetter && !$0.isNumber })

    var total = 0
    for word in words {
      if titleWords.contains(where: { $0.hasPrefix(word) }) {
        total += 100 + (titleWords.first?.hasPrefix(word) == true ? 20 : 0)
      } else if haystack.contains(word) {
        total += 60
      } else if let initials = subsequenceScore(Array(word), in: Array(haystack)) {
        total += initials
      } else {
        return nil
      }
    }
    return total
  }

  /// Letters of `needle` appear in order in `haystack`; rewards runs of consecutive letters.
  private static func subsequenceScore(_ needle: [Character], in haystack: [Character]) -> Int? {
    var score = 10
    var index = haystack.startIndex
    var previous: Int?
    for character in needle {
      guard let found = haystack[index...].firstIndex(of: character) else { return nil }
      if let previous, found == previous + 1 { score += 3 }
      previous = found
      index = found + 1
    }
    return score
  }

  private static func normalize(_ text: String) -> String {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
  }
}
