import SwiftUI
import UnfocusedCore

/// A day's raw Activity: what was in front of you, when, and for how long.
struct ActivityWindow: View {
  let model: AppModel
  @State private var day = Date()

  var body: some View {
    let stretches = model.attributedActivity(on: day).filter { $0.duration >= 1 }
    let total = stretches.reduce(0) { $0 + $1.duration }
    let unfocused = stretches.filter { $0.reason == .unfocused }.reduce(0) { $0 + $1.duration }
    let titles = model.loopTitles()
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        DatePicker("Day", selection: $day, displayedComponents: .date)
          .labelsHidden()
          .fixedSize()
        Spacer()
        Text(
          "\(Duration.seconds(total).formatted(.units(width: .abbreviated))) recorded · "
            + "\(Duration.seconds(unfocused).formatted(.units(width: .abbreviated))) unfocused"
        )
        .foregroundStyle(.secondary)
        if model.activityPaused {
          Label("Paused", systemImage: "pause.circle").foregroundStyle(.orange)
        }
      }
      .padding(12)
      Divider()
      if stretches.isEmpty {
        ContentUnavailableView(
          "No Activity",
          systemImage: "clock",
          description: Text("Nothing was recorded on this day.")
        )
      } else {
        List(Array(stretches.reversed().enumerated()), id: \.offset) { _, stretch in
          HStack(alignment: .firstTextBaseline) {
            Text(stretch.start, format: .dateTime.hour().minute())
              .monospacedDigit()
              .foregroundStyle(.secondary)
              .frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
              Text(stretch.anchor.title).lineLimit(1)
              Group {
                if let loopID = stretch.loopID, let title = titles[loopID] {
                  Text("\(stretch.anchor.source.displayName) · \(title), \(stretch.reason.explanation)")
                } else {
                  Text("\(stretch.anchor.source.displayName) · Unfocused")
                }
              }
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
            }
            Spacer()
            Text(Duration.seconds(stretch.duration).formatted(.units(width: .abbreviated, maximumUnitCount: 2)))
              .monospacedDigit()
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .frame(minWidth: 520, minHeight: 400)
    .navigationTitle("Activity")
  }
}

extension Source {
  var displayName: String {
    switch self {
    case .safari: "Safari"
    case .chrome: "Chrome"
    case .firefox: "Firefox"
    case .app(let bundleID):
      NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        .map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
        ?? bundleID
    }
  }
}
