public import Foundation
import FoundationModels
import NaturalLanguage
public import UnfocusedCore

/// The Reasoner on Apple's on-device model (ADR 0002). Nothing leaves the Mac. When Apple
/// Intelligence is off or unsupported, every answer is `nil` and Core falls back to its rules.
public struct FoundationModelsReasoner: Reasoner {
  public init() {}

  private static let instructions: String = """
    You help a knowledge worker keep track of their open work items ("Loops"). \
    Answer briefly and exactly in the format asked. Never add explanations.
    """

  public var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

  /// Small on-device models judge "is this related?" poorly (they answer the same either way), but
  /// recognise leisure reliably. So the question is whether the page is leisure that has nothing to
  /// do with the work item; anything else stays with the Focused Loop, the safe default.
  public func belongs(_ activity: Anchor, to loop: LoopBrief) async -> Bool? {
    let prompt = """
      Page title: "\(activity.title)"
      Website or app: \(activity.place)
      Someone is working on: "\(loop.title)"

      Is this page entertainment, sports, games, social media, celebrity or general news, videos for fun, \
      or personal shopping, with nothing to do with what they're working on?
      Answer YES or NO.
      """
    guard let answer = await ask(prompt)?.uppercased() else { return nil }
    if answer.hasPrefix("YES") { return false }
    if answer.hasPrefix("NO") { return true }
    return nil
  }

  /// Related by meaning uses Apple's on-device sentence embeddings rather than the language model:
  /// the model answered "same" or "different" to everything in the example set, while embeddings
  /// are deterministic. The cut-off is strict, so it misses some matches but adds no wrong ones.
  public func related(to text: String, among candidates: [LoopBrief]) async -> [UUID]? {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    let language = recognizer.dominantLanguage ?? .english
    guard let embedding = NLEmbedding.sentenceEmbedding(for: language) ?? NLEmbedding.sentenceEmbedding(for: .english)
    else { return nil }
    let typed = text.lowercased()
    return candidates.filter { embedding.distance(between: typed, and: $0.title.lowercased()) < Self.relatedDistance }
      .map(\.id)
  }

  /// Cosine distance under which two titles count as the same work (tuned on the example set).
  static let relatedDistance = 1.0

  public func captureTitle(for anchor: Anchor) async -> String? {
    let prompt = """
      Turn this window title into a short to-do title (at most 8 words), keeping names and numbers.
      Drop site names like "GitHub" or "Notion".

      Example: "Re: Contract renewal – Inbox – Mail" → Reply on contract renewal
      Example: "Fix login race by ada · Pull Request #214 · acme/app · GitHub" → Review Ada's login race fix (#214)

      Window title: "\(anchor.title)"
      To-do title:
      """
    return await ask(prompt)?.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”").union(.whitespacesAndNewlines))
  }

  public func summary(of facts: String) async -> String? {
    let prompt = """
      Write two or three short, plain sentences summing up this work period for the person who did it.
      Address them as "you". Only "Finished" items are done; for the others say "worked on" or \
      "made progress on" and never imply they are done. Mention unfocused time only as a neutral fact, never as a judgement. \
      No lists, no headings, no emoji, no advice.

      \(facts)
      """
    return await ask(prompt)
  }

  /// Greedy sampling, so the same question gets the same answer. The macOS 27 SDK (Swift 6.4)
  /// renamed the argument; CI still builds with the macOS 26 SDK.
  private static var greedy: GenerationOptions {
    #if compiler(>=6.4)
      GenerationOptions(samplingMode: .greedy)
    #else
      GenerationOptions(sampling: .greedy)
    #endif
  }

  private func ask(_ prompt: String) async -> String? {
    guard isAvailable else { return nil }
    let session = LanguageModelSession(instructions: Self.instructions)
    do {
      let answer = try await session.respond(to: prompt, options: Self.greedy).content
        .trimmingCharacters(in: .whitespacesAndNewlines)
      // `REASONER_DEBUG=1 make reasoner-examples` shows the raw answers while tuning prompts.
      if ProcessInfo.processInfo.environment["REASONER_DEBUG"] != nil { print("    model: \(answer)") }
      return answer
    } catch {
      if ProcessInfo.processInfo.environment["REASONER_DEBUG"] != nil { print("    error: \(error)") }
      return nil
    }
  }
}
