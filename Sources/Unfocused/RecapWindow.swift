import AppKit
import SwiftUI
import UnfocusedCore

/// The daily or weekly Recap: what got Closed, moved forward and Captured, and where the rest of
/// the time went.
struct RecapWindow: View {
  enum Span: String, CaseIterable {
    case day = "Day"
    case week = "Week"
  }

  let model: AppModel
  @State private var span = Span.day
  @State private var date = Date()
  @State private var copied = false
  /// The prose summary for the Recap shown, keyed by its period.
  @State private var summary: (period: DateInterval, text: String)?

  var body: some View {
    let recap = span == .day ? model.recap(day: date) : model.recap(weekOf: date)
    VStack(spacing: 0) {
      toolbar(recap)
      Divider()
      if let recap {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            if let summary, summary.period == recap.period {
              Text(summary.text)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
            }
            figures(recap)
            if span == .day, !recap.timeline.isEmpty { TimelineBar(recap: recap) }
            loops("Closed", systemImage: "checkmark.circle", recap.closed.map { ($0.title, nil) })
            loops(
              "Moved forward",
              systemImage: "arrow.forward.circle",
              recap.movedForward.map { ($0.loop.title, Recap.format($0.time)) }
            )
            loops("Captured", systemImage: "plus.circle", recap.captured.map { ($0.title, nil) })
            unfocused(recap)
          }
          .padding(20)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .frame(minWidth: 520, minHeight: 480)
    .navigationTitle("Recap")
    .task(id: recap?.period) {
      guard let recap, summary?.period != recap.period else { return }
      if let text = await model.summary(of: recap) {
        withAnimation { summary = (recap.period, text) }
      }
    }
  }

  private func toolbar(_ recap: Recap?) -> some View {
    HStack {
      Picker("Span", selection: $span) {
        ForEach(Span.allCases, id: \.self) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .fixedSize()
      Button("Previous", systemImage: "chevron.left") { move(-1) }.labelStyle(.iconOnly)
      Text(title(recap)).monospacedDigit().frame(minWidth: 160)
      Button("Next", systemImage: "chevron.right") { move(1) }.labelStyle(.iconOnly)
      Spacer()
      Button(copied ? "Copied" : "Copy as Markdown", systemImage: copied ? "checkmark" : "doc.on.doc") {
        guard let recap else { return }
        NSPasteboard.general.clearContents()
        let prose = summary.flatMap { $0.period == recap.period ? $0.text : nil }
        NSPasteboard.general.setString(recap.markdown(name: placeName, summary: prose), forType: .string)
        copied = true
        Task {
          try? await Task.sleep(for: .seconds(2))
          copied = false
        }
      }
      .disabled(recap == nil)
    }
    .padding(12)
  }

  private func figures(_ recap: Recap) -> some View {
    HStack(spacing: 12) {
      figure("\(recap.closed.count)", "Closed")
      figure("\(recap.movedForward.count)", "Moved forward")
      figure("\(recap.captured.count)", "Captured")
      figure(Recap.format(recap.unfocusedTime), "Unfocused time")
    }
  }

  private func figure(_ value: String, _ label: String) -> some View {
    FigureCard(value: value, label: label)
  }

  @ViewBuilder private func loops(_ title: String, systemImage: String, _ rows: [(String, String?)]) -> some View {
    if !rows.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        Label(title, systemImage: systemImage).font(.headline)
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
          HStack {
            Text(row.0).lineLimit(1)
            Spacer()
            if let time = row.1 { Text(time).monospacedDigit().foregroundStyle(.secondary) }
          }
        }
      }
    }
  }

  @ViewBuilder private func unfocused(_ recap: Recap) -> some View {
    if recap.unfocusedTime > 0 {
      VStack(alignment: .leading, spacing: 6) {
        Label("Unfocused time · \(Recap.format(recap.unfocusedTime))", systemImage: "circle.dashed").font(.headline)
        Text("Time that didn't go toward the Focused Loop. Just so you know where it went.")
          .font(.caption)
          .foregroundStyle(.secondary)
        ForEach(recap.unfocusedBySource.prefix(8), id: \.place) { item in
          HStack {
            Text(placeName(item.place)).lineLimit(1)
            Spacer()
            Text(Recap.format(item.time)).monospacedDigit().foregroundStyle(.secondary)
          }
        }
        if !recap.unfocusedByLoop.isEmpty {
          Text("Touched other Loops").font(.subheadline.weight(.medium)).padding(.top, 6)
          ForEach(recap.unfocusedByLoop, id: \.loop.id) { item in
            HStack {
              Text(item.loop.title).lineLimit(1)
              Spacer()
              Text(Recap.format(item.time)).monospacedDigit().foregroundStyle(.secondary)
            }
          }
        }
      }
    }
  }

  private func placeName(_ place: String) -> String {
    // Websites are already readable; apps are shown by name.
    place.contains(".") && NSWorkspace.shared.urlForApplication(withBundleIdentifier: place) != nil
      ? Source.app(place).displayName : place
  }

  private func title(_ recap: Recap?) -> String {
    guard let recap else { return "" }
    switch span {
    case .day: return recap.period.start.formatted(.dateTime.weekday(.wide).day().month())
    case .week:
      let end = recap.period.end.addingTimeInterval(-1)
      return "\(recap.period.start.formatted(.dateTime.day().month())) – \(end.formatted(.dateTime.day().month()))"
    }
  }

  private func move(_ steps: Int) {
    date = Calendar.current.date(byAdding: span == .day ? .day : .weekOfYear, value: steps, to: date) ?? date
  }
}

/// The day as a bar: Focus periods in the accent color, Unfocused time in gray.
private struct TimelineBar: View {
  let recap: Recap

  var body: some View {
    let entries = recap.timeline
    let start = entries.first?.start ?? recap.period.start
    let end = entries.map(\.end).max() ?? recap.period.end
    let total = max(end.timeIntervalSince(start), 1)
    VStack(alignment: .leading, spacing: 4) {
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 4).fill(.quaternary.opacity(0.4))
          ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
            RoundedRectangle(cornerRadius: 3)
              .fill(color(entry))
              .frame(width: max(2, geometry.size.width * entry.duration / total))
              .offset(x: geometry.size.width * entry.start.timeIntervalSince(start) / total)
              .help(help(entry))
          }
        }
      }
      .frame(height: 18)
      HStack {
        Text(start, format: .dateTime.hour().minute())
        Spacer()
        Text(end, format: .dateTime.hour().minute())
      }
      .font(.caption2)
      .foregroundStyle(.secondary)
    }
  }

  private func color(_ entry: Recap.TimelineEntry) -> AnyShapeStyle {
    entry.kind == .unfocused ? AnyShapeStyle(.gray.opacity(0.5)) : AnyShapeStyle(Style.logoLinearGradient)
  }

  private func help(_ entry: Recap.TimelineEntry) -> String {
    let span = "\(entry.start.formatted(.dateTime.hour().minute()))–\(entry.end.formatted(.dateTime.hour().minute()))"
    switch entry.kind {
    case .focus(let id): return "\(recap.titles[id] ?? "Focus") · \(span)"
    case .unfocused: return "Unfocused · \(span)"
    }
  }
}
