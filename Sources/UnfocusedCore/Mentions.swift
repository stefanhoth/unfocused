import Foundation

/// Finds `@name` mentions in a typed title.
///
/// A mention matches the longest known Person name right after the `@` (ignoring case and
/// accents); otherwise it's the single word after the `@`. The `@` is removed from the title.
enum Mentions {
  struct Result: Equatable {
    var title: String
    var names: [String]
  }

  static func parse(_ text: String, knownNames: [String]) -> Result {
    let known = knownNames.sorted { $0.count > $1.count }
    var title = ""
    var names: [String] = []
    var index = text.startIndex

    while index < text.endIndex {
      let character = text[index]
      let atWordStart = index == text.startIndex || text[text.index(before: index)].isWhitespace
      guard character == "@", atWordStart else {
        title.append(character)
        index = text.index(after: index)
        continue
      }
      let rest = text[text.index(after: index)...]
      if let name = known.first(where: { startsWithName(rest, $0) }) {
        let end = rest.index(rest.startIndex, offsetBy: name.count)
        title += rest[rest.startIndex..<end]
        names.append(name)
        index = end
      } else {
        let word = rest.prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "'" || $0 == "." }
        let trimmedWord = word.hasSuffix(".") ? word.dropLast() : word[...]
        guard !trimmedWord.isEmpty else {
          title.append(character)
          index = text.index(after: index)
          continue
        }
        title += trimmedWord
        names.append(String(trimmedWord))
        index = trimmedWord.endIndex
      }
    }
    return Result(title: title, names: names)
  }

  private static func startsWithName(_ text: Substring, _ name: String) -> Bool {
    guard text.count >= name.count else { return false }
    let candidate = text.prefix(name.count)
    guard NameMatching.key(String(candidate)) == NameMatching.key(name) else { return false }
    let after = text.dropFirst(name.count).first
    return after.map { !($0.isLetter || $0.isNumber) } ?? true
  }
}
