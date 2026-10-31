import SwiftUI
import UnfocusedCore

/// A day's raw Activity: what was in front of you, when, and for how long.
struct ActivityWindow: View {
  let model: AppModel
  @State private var day = Date()

  var body: some View {
    let stretches = model.attributedActivity(on: day).filter { $0.duration >= 1 }
    let total = stretches.reduce(0) { $0 + $1.duration }
    let unfocused = stretches.filter { $0.isUnfocusedTime }.reduce(0) { $0 + $1.duration }
    let titles = model.loopTitles()
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Button("Previous day", systemImage: "chevron.left") { move(-1) }.labelStyle(.iconOnly)
        DatePicker("Day", selection: $day, displayedComponents: .date)
          .labelsHidden()
          .fixedSize()
        Button("Next day", systemImage: "chevron.right") { move(1) }.labelStyle(.iconOnly)
        Spacer()
        Text(
          "\(Duration.seconds(total).formatted(.units(width: .abbreviated))) recorded · "
            + "\(Duration.seconds(unfocused).formatted(.units(width: .abbreviated))) unfocused"
        )
        .foregroundStyle(.secondary)
        if model.activityPaused {
          Label("Recording paused", systemImage: "pause.circle").foregroundStyle(.secondary)
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
                  Text(
                    "\(stretch.anchor.source.displayName) · \(Text(title).fontWeight(.medium).foregroundStyle(.primary)), \(stretch.reason.explanation)"
                  )
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

  private func move(_ days: Int) {
    day = Calendar.current.date(byAdding: .day, value: days, to: day) ?? day
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
