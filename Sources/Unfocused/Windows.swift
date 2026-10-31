import SwiftUI
import UnfocusedCore

/// The full window: Loops by state, with each Loop's details and history.
struct LoopsWindow: View {
  let model: AppModel

  @State private var state: LoopState = .open
  @State private var selectedID: Loop.ID?
  /// What was just Closed or let go, with Undo (DESIGN.md: every action answers).
  @State private var confirmation: Confirmation?

  private var loops: [Loop] {
    state == .open ? model.openLoops : model.loops(in: state)
  }

  var body: some View {
    // A fixed-width list next to the detail: split views drifted and clipped the detail.
    HStack(spacing: 0) {
      VStack(spacing: 0) {
        Picker("Show", selection: $state) {
          Text("Open").tag(LoopState.open)
          Text("Closed").tag(LoopState.closed)
          Text("Let go").tag(LoopState.letGo)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(12)
        if loops.isEmpty {
          emptyState.frame(maxHeight: .infinity)
        } else {
          SelectableList(items: loops, selection: $selectedID) { loop in
            LoopRow(
              loop: loop,
              isFocused: loop.id == model.focusedLoop?.id,
              aging: model.aging[loop.id],
              age: model.lastEngagement(of: loop) ?? loop.capturedAt
            )
            .contextMenu { actions(for: loop) }
          }
        }
      }
      .frame(width: 340)
      Divider()
      Group {
        if let loop = loops.first(where: { $0.id == selectedID }) {
          LoopDetail(model: model, loop: loop, finish: finish)
        } else {
          Text("Select a Loop to see where you left off").foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(minWidth: 680, minHeight: 400)
    .overlay(alignment: .bottom) {
      if let confirmation {
        HStack(spacing: 10) {
          ConfirmationBar(confirmation: confirmation)
          if let undo = confirmation.undo {
            Button("Undo") {
              undo()
              withAnimation { self.confirmation = nil }
            }
            .keyboardShortcut("z", modifiers: .command)
          }
        }
        .padding(.bottom, 18)
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .navigationTitle("Loops")
    .onAppear { model.refresh() }
    .onChange(of: state) { selectedID = nil }
  }

  @ViewBuilder private var emptyState: some View {
    switch state {
    case .open:
      ContentUnavailableView(
        "No Open Loops",
        systemImage: "circle.dashed",
        description: Text("Press \(model.hotKey.label) anywhere to capture one.")
      )
    case .closed:
      ContentUnavailableView("Nothing Closed yet", systemImage: "checkmark.circle")
    case .letGo:
      ContentUnavailableView("Nothing let go", systemImage: "arrow.down.circle")
    }
  }

  @ViewBuilder private func actions(for loop: Loop) -> some View {
    Button("Edit…") { model.editLoop?(loop) }
    if loop.state == .open {
      Button("Focus") { model.focus(loop) }
      Button("Close Loop") { finish(loop, true) }
      Button("Let go") { finish(loop, false) }
    } else {
      Button("Reopen") { model.reopen(loop) }
    }
  }

  /// Closes or lets go of `loop`, then confirms with Undo, as in the panel.
  private func finish(_ loop: Loop, _ close: Bool) {
    withAnimation(.snappy) {
      _ = close ? model.close(loop) : model.letGo(loop)
    }
    if close { NSSound(named: "Glass")?.play() }
    let confirmation = Confirmation(
      text: close ? "Closed “\(loop.title)”" : "Let go of “\(loop.title)”",
      systemImage: close ? "checkmark.circle.fill" : "arrow.down.circle",
      celebrate: close,
      undo: { [model] in model.reopen(loop) }
    )
    withAnimation(.snappy) { self.confirmation = confirmation }
    Task {
      try? await Task.sleep(for: .seconds(4))
      if self.confirmation?.id == confirmation.id { withAnimation { self.confirmation = nil } }
    }
  }
}

/// A Loop in a list, like the panel's rows: aging, title, Where I left off, how long ago.
private struct LoopRow: View {
  let loop: Loop
  let isFocused: Bool
  let aging: LoopAging?
  let age: Date

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      AgingMark(aging: aging)
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(loop.title).lineLimit(2)
          if isFocused {
            Image(nsImage: MenuBarGlyph.image(focused: true))
              .renderingMode(.template)
              .foregroundStyle(Style.logoLinearGradient)
              .help("Focused")
          }
        }
        LooseEndNote(aging: aging)
        if let note = loop.whereILeftOff {
          Text(note).font(.callout).foregroundStyle(.secondary).lineLimit(1)
        }
      }
      Spacer(minLength: 8)
      Text(PanelView.shortAge(age)).font(.caption).monospacedDigit().foregroundStyle(.tertiary)
    }
  }
}

/// A Loop in the Loops section: the same summary as the panel, its actions as buttons, then what
/// happened (time spent and history). Editing happens in Edit Loop.
private struct LoopDetail: View {
  let model: AppModel
  let loop: Loop
  let finish: (Loop, Bool) -> Void

  var body: some View {
    let sessions = model.focusSessions(for: loop)
    let log = model.workLog(for: loop)
    ScrollView {
      VStack(alignment: .leading, spacing: 26) {
        LoopSummary(model: model, loop: loop) { actionButtons }

        if !log.isEmpty {
          let total = log.reduce(0) { $0 + $1.duration }
          section("Worked on · \(Duration.seconds(total).formatted(.units(width: .abbreviated))) in 30 days") {
            ForEach(Array(log.prefix(20).enumerated()), id: \.offset) { _, piece in
              WorkLogRow(piece: piece)
            }
          }
        }

        section("History") {
          ForEach(Array(model.history(for: loop).enumerated()), id: \.offset) { _, event in
            LabeledContent(event.change.label) {
              Text(event.at, format: .dateTime.day().month().hour().minute())
            }
          }
          ForEach(Array(sessions.enumerated()), id: \.offset) { _, session in
            LabeledContent("Focused") {
              Text(session.start, format: .dateTime.day().month().hour().minute())
              Text(
                session.end == nil
                  ? "· now" : "· \(Duration.seconds(session.duration).formatted(.units(width: .abbreviated)))"
              )
            }
          }
        }
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder private var actionButtons: some View {
    HStack(spacing: 8) {
      if loop.state == .open {
        Button("Focus") { model.focus(loop) }
          .buttonStyle(.borderedProminent)
        Button("Close Loop") { finish(loop, true) }
        Button("Let go") { finish(loop, false) }
      } else {
        Button("Reopen") { model.reopen(loop) }
          .buttonStyle(.borderedProminent)
      }
      Button("Edit…") { model.editLoop?(loop) }
        .keyboardShortcut("e", modifiers: .command)
    }
  }

  private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.headline)
      content()
    }
  }
}

/// Settings for the optional daily Tie-off notification.
private struct TieOffReminderSection: View {
  let reminder: TieOffReminder
  @State private var enabled = false
  @State private var time = Date()

  var body: some View {
    Section("Tie-off") {
      Toggle("Remind me to tie off Loose Ends every day", isOn: $enabled)
        .onChange(of: enabled) { reminder.setEnabled(enabled) }
      if enabled {
        DatePicker("At", selection: $time, displayedComponents: .hourAndMinute)
          .onChange(of: time) {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
            reminder.setMinuteOfDay((parts.hour ?? 16) * 60 + (parts.minute ?? 30))
          }
      }
      Text("Only when there are Loose Ends. This is the only notification unfocused sends.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .onAppear {
      enabled = reminder.isEnabled
      let minute = reminder.minuteOfDay
      time = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
    }
  }
}

/// One entry of a Loop's work log: when, where, how long, and why it counts toward the Loop.
private struct WorkLogRow: View {
  let piece: AttributedStretch

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        Text(piece.anchor.title).lineLimit(1)
        Text("\(piece.start.formatted(.dateTime.day().month().hour().minute())) · \(piece.reason.explanation)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Text(Duration.seconds(piece.duration).formatted(.units(width: .abbreviated, maximumUnitCount: 2)))
        .monospacedDigit()
        .foregroundStyle(.secondary)
    }
  }
}

extension AttributionReason {
  /// Why time counts toward a Loop, in the user's words.
  var explanation: String {
    switch self {
    case .anchor: "in one of its Anchors"
    case .focus: "while it was Focused"
    case .unfocused: "Unfocused time"
    case .judgedUnrelated: "judged unrelated to the Focused Loop"
    }
  }
}

extension LoopChange {
  var label: String {
    switch self {
    case .captured: "Captured"
    case .closed: "Closed"
    case .letGo: "Let go"
    case .reopened: "Reopened"
    }
  }
}

/// The main window's Settings section.
struct SettingsView: View {
  let model: AppModel
  let reminder: TieOffReminder?

  var body: some View {
    Form {
      Picker(
        "Open the panel with",
        selection: Binding(get: { model.hotKey }, set: { model.useHotKey($0) })
      ) {
        ForEach(HotKeyChoice.allCases) { choice in
          Text(choice.label).tag(choice)
        }
      }
      if let problem = model.hotKeyProblem {
        Label(problem, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.orange)
      }
      if let reminder {
        TieOffReminderSection(reminder: reminder)
      }
      Section("Loose Ends") {
        Stepper(
          "A Loop is a Loose End after \(model.looseEndThreshold) active days untouched",
          value: Binding(get: { model.looseEndThreshold }, set: { model.looseEndThreshold = $0 }),
          in: 1...30
        )
        Text("Only days you used your Mac count, so weekends and holidays don't age your Loops.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Section("Focus") {
        Picker(
          "Pause Focus after",
          selection: Binding(get: { model.focusIdleMinutes }, set: { model.focusIdleMinutes = $0 })
        ) {
          ForEach([10, 15, 20, 30, 45, 60], id: \.self) { Text("\($0) minutes idle").tag($0) }
        }
        Text("Locking the screen pauses Focus right away; sleep or shutdown ends it.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Section("Activity") {
        Stepper(
          "Keep Activity for \(model.activityRetentionDays) days",
          value: Binding(get: { model.activityRetentionDays }, set: { model.activityRetentionDays = $0 }),
          in: 7...365,
          step: 7
        )
        VStack(alignment: .leading) {
          Text("Never record these apps (bundle identifiers, one per line):")
          TextEditor(
            text: Binding(
              get: { model.excludedApps.joined(separator: "\n") },
              set: { model.excludedApps = $0.split(separator: "\n").map(String.init) }
            )
          )
          .font(.body.monospaced())
          .frame(height: 80)
          Text("Private browser windows are never recorded.").font(.caption).foregroundStyle(.secondary)
        }
      }
      Section("Intelligence") {
        Label(
          model.reasonerAvailable
            ? "On-device model available. It judges unclear Focus time, finds related Loops and suggests titles."
            : "On-device model unavailable (Apple Intelligence is off or unsupported). unfocused uses its rules.",
          systemImage: model.reasonerAvailable ? "sparkles" : "sparkles.slash"
        )
        .font(.callout)
        Text("Everything runs on this Mac. Nothing is sent anywhere.").font(.caption).foregroundStyle(.secondary)
      }
      Section("Troubleshooting") {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("Export diagnostics")
            Text("Logs and app version only. No Loops, People or Activity.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Button("Export…") { DiagnosticsExporter.exportInteractively(core: model.core, log: model.log) }
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle("Settings")
  }
}
