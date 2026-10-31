import SwiftUI

struct SampleLoop: Identifiable {
  let id = UUID()
  let title: String
  let note: String?
  let aging: Double
  let followUp: String?
  let person: String?
  let source: String
}

enum Sample {
  static let context = "notion.so · Q3 Hiring plan"
  static let typed = "Hiring plan feedback for @Ada"
  static let focused = SampleLoop(
    title: "Write the onboarding spec",
    note: "Halfway through section 2, permissions",
    aging: 0,
    followUp: nil,
    person: nil,
    source: "Notion"
  )
  static let loops: [SampleLoop] = [
    SampleLoop(
      title: "Contract renewal from Acme",
      note: "Sent questions on clause 4",
      aging: 1,
      followUp: "Ada",
      person: "Ada",
      source: "Mail"
    ),
    SampleLoop(
      title: "Review Jonas' PR #214",
      note: nil,
      aging: 1,
      followUp: nil,
      person: "Jonas",
      source: "GitHub"
    ),
    SampleLoop(
      title: "Q3 hiring plan",
      note: "Need budget numbers",
      aging: 0.66,
      followUp: nil,
      person: nil,
      source: "Notion"
    ),
    SampleLoop(
      title: "Book offsite venue",
      note: nil,
      aging: 0.33,
      followUp: nil,
      person: nil,
      source: "Safari"
    ),
  ]
  static let tieOff = loops[0]
}
