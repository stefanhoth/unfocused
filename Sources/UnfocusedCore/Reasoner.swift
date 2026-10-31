public import Foundation
import GRDB

/// What a Reasoner gets to know about a Loop: enough to judge, nothing more.
public struct LoopBrief: Hashable, Sendable {
  public let id: UUID
  public let title: String
  public let whereILeftOff: String?
  /// Titles of its Anchors.
  public let anchors: [String]
  public let people: [String]

  public init(id: UUID, title: String, whereILeftOff: String?, anchors: [String], people: [String]) {
    self.id = id
    self.title = title
    self.whereILeftOff = whereILeftOff
    self.anchors = anchors
    self.people = people
  }
}

/// Judgement calls the rules can't make, answered on the device (ADR 0002). Every answer may be
/// `nil` ("can't tell", or no model available); Core then falls back to its rules.
public protocol Reasoner: Sendable {
  /// Whether time on `activity` during a Focus on `loop` was work on that Loop.
  func belongs(_ activity: Anchor, to loop: LoopBrief) async -> Bool?
  /// Which of `candidates` are about the same thing as `text`, by meaning.
  func related(to text: String, among candidates: [LoopBrief]) async -> [UUID]?
  /// A short Loop title for what's in front of the user.
  func captureTitle(for anchor: Anchor) async -> String?
  /// A few plain sentences summing up a Recap, from its facts.
  func summary(of facts: String) async -> String?
}

extension Reasoner {
  public func summary(of facts: String) async -> String? { nil }
}

struct JudgementRecord: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "judgement"

  var identifier: String
  var loopId: String
  var belongs: Bool
  var judgedAt: Double
}

extension Core {
  // MARK: Attribution with a Reasoner

  /// Asks the Reasoner about time during Focus that matched none of the Focused Loop's Anchors,
  /// once per page and Loop, and keeps its verdicts. Time it judges unrelated becomes Unfocused time.
  public func judgeFocusActivity(from: Date, to: Date, with reasoner: some Reasoner) async throws {
    let pending = try attributedActivity(from: from, to: to).filter { $0.reason == .focus }
    var seen = Set<String>()
    for piece in pending {
      guard let loopID = piece.loopID, seen.insert("\(piece.anchor.identifier)|\(loopID)").inserted,
        try !hasJudgement(piece.anchor.identifier, loopID),
        let brief = try brief(of: loopID)
      else { continue }
      guard let verdict = await reasoner.belongs(piece.anchor, to: brief) else { continue }
      let judgedAt = time.now.timeIntervalSince1970
      try await database.writer.write { db in
        try JudgementRecord(
          identifier: piece.anchor.identifier,
          loopId: loopID.uuidString,
          belongs: verdict,
          judgedAt: judgedAt
        )
        .insert(db, onConflict: .replace)
      }
    }
  }

  // MARK: Capture with a Reasoner

  /// Related Loops by the rules plus, when the Reasoner can tell, by meaning.
  public func relatedLoops(toCapture text: String, anchor: Anchor?, reasoner: some Reasoner) async throws
    -> [RelatedLoop]
  {
    var byMeaning = Set<UUID>()
    if !text.trimmingCharacters(in: .whitespaces).isEmpty {
      let briefs = try openLoops().compactMap { try brief(of: $0.id) }
      byMeaning = Set(await reasoner.related(to: text, among: briefs) ?? [])
    }
    return try relatedLoops(toCapture: text, anchor: anchor, meaningMatches: byMeaning)
  }

  /// A title to prefill Capture with: the Reasoner's suggestion, or the Anchor's own title.
  public func captureTitle(for anchor: Anchor, reasoner: some Reasoner) async -> String {
    let suggestion = await reasoner.captureTitle(for: anchor)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return suggestion.isEmpty ? anchor.title : String(suggestion.prefix(120))
  }

  // MARK: Recap prose

  /// A short prose summary of a Recap, or `nil` without a model (the Recap then shows figures only).
  public func summary(of recap: Recap, reasoner: some Reasoner) async -> String? {
    guard !recap.closed.isEmpty || !recap.movedForward.isEmpty || !recap.captured.isEmpty || recap.unfocusedTime > 0
    else { return nil }
    let text = await reasoner.summary(of: recap.facts)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return text.isEmpty ? nil : text
  }

  // MARK: Helpers

  /// Verdicts by "identifier|loopID".
  static func judgements(_ db: Database) throws -> [String: Bool] {
    try JudgementRecord.fetchAll(db).reduce(into: [:]) { result, record in
      result["\(record.identifier)|\(record.loopId)"] = record.belongs
    }
  }

  private func hasJudgement(_ identifier: String, _ loopID: UUID) throws -> Bool {
    try database.writer.read { db in
      try JudgementRecord.filter(Column("identifier") == identifier && Column("loopId") == loopID.uuidString)
        .fetchCount(db) > 0
    }
  }

  private func brief(of loopID: UUID) throws -> LoopBrief? {
    guard let loop = try loop(loopID) else { return nil }
    return LoopBrief(
      id: loop.id,
      title: loop.title,
      whereILeftOff: loop.whereILeftOff,
      anchors: try anchors(of: loopID).map(\.title),
      people: try people(of: loopID).map(\.person.name)
    )
  }
}
