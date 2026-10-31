import Foundation
import Synchronization
import Testing
import UnfocusedCore

private func page(_ path: String, _ title: String? = nil) -> Anchor {
  guard let anchor = Anchor.webPage(url: "https://example.com/\(path)", title: title ?? path, source: .safari) else {
    preconditionFailure("test URL must be valid")
  }
  return anchor
}

private func spend(_ minutes: Int, on anchor: Anchor, _ core: Core, _ time: TestTime) throws {
  try core.recordActivity(anchor)
  for _ in 0..<minutes {
    time.advance(by: .minutes(1))
    try core.recordActivity(anchor)
  }
}

/// A Reasoner with canned answers. `nil` answers stand for "the model can't tell / isn't there".
final class FakeReasoner: Reasoner {
  let unrelatedTitles: Set<String>
  let meaningMatches: [String]
  let title: String?
  let judged = Mutex(0)

  init(unrelatedTitles: Set<String> = [], meaningMatches: [String] = [], title: String? = nil) {
    self.unrelatedTitles = unrelatedTitles
    self.meaningMatches = meaningMatches
    self.title = title
  }

  func belongs(_ activity: Anchor, to loop: LoopBrief) async -> Bool? {
    judged.withLock { $0 += 1 }
    return !unrelatedTitles.contains(activity.title)
  }

  func related(to text: String, among candidates: [LoopBrief]) async -> [UUID]? {
    candidates.filter { meaningMatches.contains($0.title) }.map(\.id)
  }

  func captureTitle(for anchor: Anchor) async -> String? { title }
}

/// The model isn't available: every answer is "can't tell".
struct UnavailableReasoner: Reasoner {
  func belongs(_ activity: Anchor, to loop: LoopBrief) async -> Bool? { nil }
  func related(to text: String, among candidates: [LoopBrief]) async -> [UUID]? { nil }
  func captureTitle(for anchor: Anchor) async -> String? { nil }
}

@Suite("Reasoner")
struct ReasonerTests {
  @Test("unmatched Activity during Focus that the Reasoner judges unrelated becomes Unfocused time")
  func judgesFocusTime() async throws {
    let (core, time) = try makeCore()
    let start = time.now
    let spec = try core.capture(title: "Write the spec")
    try core.focus(spec.id)
    try spend(10, on: page("rfc", "RFC 9110"), core, time)
    try spend(5, on: page("news", "Football results"), core, time)

    let reasoner = FakeReasoner(unrelatedTitles: ["Football results"])
    try await core.judgeFocusActivity(from: start, to: time.now, with: reasoner)

    let attributed = try core.attributedActivity(from: start, to: time.now)
    #expect(attributed.map(\.loopID) == [spec.id, nil])
    #expect(attributed.map(\.reason) == [.focus, .judgedUnrelated])
    #expect(try core.unfocusedTime(from: start, to: time.now) == .minutes(5))
  }

  @Test("each page is judged once per Loop")
  func judgesOnce() async throws {
    let (core, time) = try makeCore()
    let start = time.now
    let spec = try core.capture(title: "Write the spec")
    try core.focus(spec.id)
    try spend(3, on: page("rfc"), core, time)
    try spend(3, on: page("other"), core, time)
    try spend(3, on: page("rfc"), core, time)

    let reasoner = FakeReasoner()
    try await core.judgeFocusActivity(from: start, to: time.now, with: reasoner)
    try await core.judgeFocusActivity(from: start, to: time.now, with: reasoner)
    #expect(reasoner.judged.withLock { $0 } == 2)
  }

  @Test("Activity in a Loop's own Anchor isn't second-guessed")
  func anchorsNotJudged() async throws {
    let (core, time) = try makeCore()
    let start = time.now
    let spec = try core.capture(title: "Write the spec", anchor: page("spec", "Football results"))
    try core.focus(spec.id)
    try spend(3, on: page("spec", "Football results"), core, time)

    let reasoner = FakeReasoner(unrelatedTitles: ["Football results"])
    try await core.judgeFocusActivity(from: start, to: time.now, with: reasoner)
    #expect(reasoner.judged.withLock { $0 } == 0)
    #expect(try core.attributedActivity(from: start, to: time.now).map(\.reason) == [.anchor])
  }

  @Test("without a model, Focus time stays with the Focused Loop")
  func fallbackAttribution() async throws {
    let (core, time) = try makeCore()
    let start = time.now
    let spec = try core.capture(title: "Write the spec")
    try core.focus(spec.id)
    try spend(5, on: page("news", "Football results"), core, time)

    try await core.judgeFocusActivity(from: start, to: time.now, with: UnavailableReasoner())
    #expect(try core.attributedActivity(from: start, to: time.now).map(\.reason) == [.focus])
  }

  @Test("related Loops include matches by meaning")
  func relatedByMeaning() async throws {
    let (core, _) = try makeCore()
    let budget = try core.capture(title: "Q3 spending forecast")
    _ = try core.capture(title: "Book flights")

    let reasoner = FakeReasoner(meaningMatches: ["Q3 spending forecast"])
    let related = try await core.relatedLoops(
      toCapture: "budget numbers for next quarter",
      anchor: nil,
      reasoner: reasoner
    )
    #expect(related.map(\.loop.id) == [budget.id])
    #expect(related.first?.reasons == [.similarMeaning])
  }

  @Test("without a model, related Loops fall back to the rules")
  func fallbackRelated() async throws {
    let (core, _) = try makeCore()
    let budget = try core.capture(title: "Budget proposal")
    let related = try await core.relatedLoops(
      toCapture: "budget proposal draft",
      anchor: nil,
      reasoner: UnavailableReasoner()
    )
    #expect(related.map(\.loop.id) == [budget.id])
  }

  @Test("the Capture title comes from the Reasoner, or falls back to the Anchor's title")
  func captureTitle() async throws {
    let (core, _) = try makeCore()
    let anchor = page("pr", "Fix login race by ada · Pull Request #214 · acme/app · GitHub")

    let suggested = await core.captureTitle(for: anchor, reasoner: FakeReasoner(title: "Review Ada's login fix (#214)"))
    #expect(suggested == "Review Ada's login fix (#214)")

    #expect(await core.captureTitle(for: anchor, reasoner: UnavailableReasoner()) == anchor.title)
    #expect(await core.captureTitle(for: anchor, reasoner: FakeReasoner(title: "   ")) == anchor.title)
  }
}
