// The Reasoner's manual example set (#21): runs each case against the real on-device model and
// compares with what a person would answer. Not part of CI; the model isn't there. Run with
// `make reasoner-examples` after changing a prompt, and note the score in the PR.
import Foundation
import UnfocusedCore
import UnfocusedReasoner

func page(_ url: String, _ title: String) -> Anchor {
  Anchor.webPage(url: url, title: title, source: .safari)
    ?? Anchor(source: .safari, identifier: url, link: url, title: title)
}

func brief(_ title: String, leftOff: String? = nil, anchors: [String] = [], people: [String] = []) -> LoopBrief {
  LoopBrief(id: UUID(), title: title, whereILeftOff: leftOff, anchors: anchors, people: people)
}

let reasoner = FoundationModelsReasoner()
guard reasoner.isAvailable else {
  print("The on-device model isn't available (Apple Intelligence off or unsupported).")
  exit(1)
}

let spec = brief(
  "Write the onboarding API spec",
  leftOff: "Section 2: permissions",
  anchors: ["Onboarding API spec – Notion"],
  people: ["Ada"]
)
let offsite = brief("Book the team offsite venue", anchors: ["Venues in Lisbon"])

let belongsCases: [(Anchor, LoopBrief, Bool)] = [
  (page("https://datatracker.ietf.org/doc/html/rfc9110", "RFC 9110: HTTP Semantics"), spec, true),
  (page("https://developer.apple.com/documentation/oauth", "OAuth scopes | Apple Developer"), spec, true),
  (page("https://www.espn.com/soccer/scores", "Soccer Scores – ESPN"), spec, false),
  (page("https://www.youtube.com/watch?v=x", "Funny cats compilation – YouTube"), spec, false),
  (page("https://www.airbnb.com/s/Lisbon", "Lisbon – Stays – Airbnb"), offsite, true),
  (page("https://github.com/acme/app/pull/214", "Fix login race · Pull Request #214"), offsite, false),
]

let candidates = [
  brief("Q3 spending forecast"), brief("Book the team offsite venue"), brief("Review Jonas' PR #214"),
  brief("Renew the Acme contract"),
]
let relatedCases: [(String, Set<String>)] = [
  ("budget numbers for next quarter", ["Q3 spending forecast"]),
  ("find a hotel for the team retreat", ["Book the team offsite venue"]),
  ("call the dentist", []),
  ("contract renewal with Acme", ["Renew the Acme contract"]),
  ("look at the pull request from Jonas", ["Review Jonas' PR #214"]),
]

let titleCases = [
  page("https://github.com/acme/app/pull/214", "Fix login race by ada · Pull Request #214 · acme/app · GitHub"),
  page("https://www.notion.so/acme/Q3-Hiring-plan", "Q3 Hiring plan"),
]

var correct = 0
var total = 0
print("== Does this time belong to the Focused Loop? ==")
for (activity, loop, expected) in belongsCases {
  let answer = await reasoner.belongs(activity, to: loop)
  total += 1
  if answer == expected { correct += 1 }
  print(
    "\(answer == expected ? "✔" : "✘") \(activity.title)  →  \(loop.title): \(answer.map(String.init) ?? "can't tell")"
  )
}

print("\n== Related by meaning ==")
for (text, expected) in relatedCases {
  let ids = await reasoner.related(to: text, among: candidates) ?? []
  let titles = Set(candidates.filter { ids.contains($0.id) }.map(\.title))
  total += 1
  if titles == expected { correct += 1 }
  print("\(titles == expected ? "✔" : "✘") \(text)  →  \(titles.sorted())")
}

print("\n== Capture titles (judge by eye) ==")
for anchor in titleCases {
  print("· \(anchor.title)  →  \(await reasoner.captureTitle(for: anchor) ?? "(none)")")
}

print("\n== Recap summary (judge by eye) ==")
let facts = """
  Period: a day
  Finished: Renew the Acme contract; Review Jonas' PR #214
  Worked on, not finished yet: Write the onboarding API spec (2h 10m); Book the team offsite venue (25m)
  New ideas noted for later: Q3 spending forecast
  Unfocused time: 1h 5m
  """
print(await reasoner.summary(of: facts) ?? "(none)")

print("\n\(correct) of \(total) judged cases as expected.")
