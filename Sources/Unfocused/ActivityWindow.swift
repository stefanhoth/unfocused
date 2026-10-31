import SwiftUI
import UnfocusedCore

/// A day's Activity, structured like the Recap: figures, a timeline, then what was in front of you,
/// grouped by hour, each entry naming the Loop it counted toward.
struct ActivityWindow: View {
  let model: AppModel
  @State private var day = Date()

  var body: some View {
    let entries = Self.merge(model.attributedActivity(on: day).filter { $0.duration >= 1 })
    let total = entries.reduce(0) { $0 + $1.duration }
    let unfocused = entries.filter(\.isUnfocusedTime).reduce(0) { $0 + $1.duration }
    let towardLoops = entries.filter { $0.loopID != nil }.reduce(0) { $0 + $1.duration }
    let titles = model.loopTitles()
    VStack(spacing: 0) {
      toolbar
      Divider()
      if entries.isEmpty {
        ContentUnavailableView(
          "No Activity",
          systemImage: "clock",
          description: Text(model.activityPaused ? "Recording is paused." : "Nothing was recorded on this day.")
        )
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
              FigureCard(value: Style.shortDuration(total), label: "Recorded")
              FigureCard(value: Style.shortDuration(towardLoops), label: "Toward Loops")
              FigureCard(value: Style.shortDuration(unfocused), label: "Unfocused time")
            }
            ActivityTimeline(entries: entries)
            ForEach(Self.byHour(entries.reversed()), id: \.hour) { group in
              VStack(alignment: .leading, spacing: 4) {
                Text(group.hour, format: .dateTime.hour().minute())
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
                ForEach(Array(group.entries.enumerated()), id: \.offset) { _, entry in
                  ActivityRow(entry: entry, loopTitle: entry.loopID.flatMap { titles[$0] })
                }
              }
            }
          }
          .padding(20)
        }
      }
    }
    .frame(minWidth: 560, minHeight: 420)
    .navigationTitle("Activity")
  }

  private var toolbar: some View {
    HStack(spacing: 10) {
      Button("Previous day", systemImage: "chevron.left") { move(-1) }.labelStyle(.iconOnly)
      Text(day, format: .dateTime.weekday(.wide).day().month())
        .font(.headline)
        .frame(minWidth: 150)
      Button("Next day", systemImage: "chevron.right") { move(1) }.labelStyle(.iconOnly)
      if !Calendar.current.isDateInToday(day) {
        Button("Today") { day = Date() }
      }
      Spacer()
      if model.activityPaused {
        Label("Recording paused", systemImage: "pause.circle").foregroundStyle(.secondary)
      }
    }
    .padding(12)
  }

  private func move(_ days: Int) {
    day = Calendar.current.date(byAdding: .day, value: days, to: day) ?? day
  }

  /// Joins consecutive stretches in the same place that count the same way, so the list reads as
  /// what you did, not every sample.
  static func merge(_ stretches: [AttributedStretch]) -> [AttributedStretch] {
    var merged: [AttributedStretch] = []
    for piece in stretches {
      if let last = merged.last, last.anchor.identifier == piece.anchor.identifier, last.loopID == piece.loopID,
        last.reason == piece.reason, piece.start.timeIntervalSince(last.end) <= 120
      {
        merged[merged.count - 1] = AttributedStretch(
          anchor: piece.anchor,
          start: last.start,
          end: piece.end,
          loopID: piece.loopID,
          reason: piece.reason,
          focusedLoopID: piece.focusedLoopID
        )
      } else {
        merged.append(piece)
      }
    }
    return merged
  }

  /// Entries grouped by the hour they started in, newest first.
  static func byHour(_ entries: [AttributedStretch]) -> [(hour: Date, entries: [AttributedStretch])] {
    var groups: [(hour: Date, entries: [AttributedStretch])] = []
    for entry in entries {
      let hour = Calendar.current.dateInterval(of: .hour, for: entry.start)?.start ?? entry.start
      if groups.last?.hour == hour {
        groups[groups.count - 1].entries.append(entry)
      } else {
        groups.append((hour, [entry]))
      }
    }
    return groups
  }
}

private struct ActivityRow: View {
  let entry: AttributedStretch
  let loopTitle: String?

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Text(entry.start, format: .dateTime.hour().minute())
        .font(.callout)
        .monospacedDigit()
        .foregroundStyle(.tertiary)
        .frame(width: 44, alignment: .leading)
      AppIcon(bundleID: entry.anchor.source.bundleID, size: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(entry.anchor.title).lineLimit(1)
        if let loopTitle {
          HStack(spacing: 5) {
            Image(nsImage: MenuBarGlyph.image(focused: false))
              .renderingMode(.template)
              .resizable()
              .frame(width: 11, height: 11)
              .foregroundStyle(Style.logoLinearGradient)
            Text(loopTitle).font(.caption.weight(.medium))
            Text(entry.reason.explanation).font(.caption).foregroundStyle(.secondary)
          }
        } else {
          Text("Unfocused").font(.caption).foregroundStyle(.secondary)
        }
      }
      Spacer(minLength: 8)
      Text(Style.shortDuration(entry.duration)).font(.callout).monospacedDigit().foregroundStyle(.secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(RoundedRectangle(cornerRadius: Style.rowRadius).fill(Color.primary.opacity(0.04)))
    .opacity(entry.isUnfocusedTime && loopTitle == nil ? 0.75 : 1)
  }
}

/// The day as one bar: time toward a Loop in the logo gradient, Unfocused time gray.
private struct ActivityTimeline: View {
  let entries: [AttributedStretch]

  var body: some View {
    let start = entries.first?.start ?? Date()
    let end = entries.map(\.end).max() ?? start
    let span = max(end.timeIntervalSince(start), 1)
    VStack(alignment: .leading, spacing: 4) {
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 4).fill(.quaternary.opacity(0.4))
          ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
            RoundedRectangle(cornerRadius: 3)
              .fill(entry.loopID == nil ? AnyShapeStyle(.gray.opacity(0.5)) : AnyShapeStyle(Style.logoLinearGradient))
              .frame(width: max(2, geometry.size.width * entry.duration / span))
              .offset(x: geometry.size.width * entry.start.timeIntervalSince(start) / span)
          }
        }
      }
      .frame(height: 14)
      HStack {
        Text(start, format: .dateTime.hour().minute())
        Spacer()
        Text(end, format: .dateTime.hour().minute())
      }
      .font(.caption2)
      .foregroundStyle(.secondary)
    }
  }
}
