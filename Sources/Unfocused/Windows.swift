import SwiftUI
import UnfocusedCore

/// The full window: Loops by state, with each Loop's details and history.
struct LoopsWindow: View {
  let model: AppModel

  @State private var state: LoopState = .open
  @State private var selectedID: Loop.ID?

  private var loops: [Loop] {
    state == .open ? model.openLoops : model.loops(in: state)
  }

  var body: some View {
    NavigationSplitView {
      List(loops, selection: $selectedID) { loop in
        LoopRow(loop: loop, isFocused: loop.id == model.focusedLoop?.id)
          .contextMenu { actions(for: loop) }
      }
      .overlay {
        if loops.isEmpty { emptyState }
      }
      .safeAreaInset(edge: .top) {
        Picker("Show", selection: $state) {
          Text("Open").tag(LoopState.open)
          Text("Closed").tag(LoopState.closed)
          Text("Dropped").tag(LoopState.dropped)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(8)
      }
      .navigationSplitViewColumnWidth(min: 260, ideal: 320)
    } detail: {
      if let loop = loops.first(where: { $0.id == selectedID }) {
        LoopDetail(model: model, loop: loop)
      } else {
        Text("Select a Loop").foregroundStyle(.secondary)
      }
    }
    .frame(minWidth: 680, minHeight: 400)
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
    case .dropped:
      ContentUnavailableView("Nothing Dropped", systemImage: "arrow.down.circle")
    }
  }

  @ViewBuilder private func actions(for loop: Loop) -> some View {
    if loop.state == .open {
      Button("Focus") { model.focus(loop) }
      Button("Close") { model.close(loop) }
      Button("Drop") { model.drop(loop) }
    } else {
      Button("Reopen") { model.reopen(loop) }
    }
  }
}

private struct LoopRow: View {
  let loop: Loop
  let isFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text(loop.title).lineLimit(2)
        if isFocused { Image(systemName: "scope").help("Focused") }
      }
      if let note = loop.whereILeftOff {
        Text(note).font(.callout).foregroundStyle(.secondary).lineLimit(1)
      }
    }
    .padding(.vertical, 2)
  }
}

private struct LoopDetail: View {
  let model: AppModel
  let loop: Loop

  var body: some View {
    let sessions = model.focusSessions(for: loop)
    let focusedTime = sessions.reduce(0) { $0 + $1.duration }
    Form {
      Section {
        Text(loop.title).font(.title2)
        if let note = loop.whereILeftOff {
          LabeledContent("Where I left off", value: note)
        }
        if focusedTime > 0 {
          LabeledContent("Focused for", value: Duration.seconds(focusedTime).formatted(.units(width: .abbreviated)))
        }
        if let engaged = model.lastEngagement(of: loop) {
          LabeledContent("Last worked on") { Text(engaged, format: .relative(presentation: .named)) }
        }
      }
      PeopleSection(model: model, loop: loop)
      let anchors = model.anchors(of: loop)
      if !anchors.isEmpty {
        Section("Anchors") {
          ForEach(Array(anchors.enumerated()), id: \.offset) { _, anchor in
            HStack {
              Button {
                AnchorOpener.open(anchor)
              } label: {
                Label(anchor.title, systemImage: "link").lineLimit(1)
              }
              .buttonStyle(.link)
              Spacer()
              Button("Remove Anchor", systemImage: "minus.circle") { model.removeAnchor(anchor, from: loop) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }
          }
        }
      }
      Section {
        HStack {
          if loop.state == .open {
            Button("Focus") { model.focus(loop) }
            Button("Close") { model.close(loop) }
            Button("Drop") { model.drop(loop) }
          } else {
            Button("Reopen") { model.reopen(loop) }
          }
        }
      }
      let log = model.workLog(for: loop)
      if !log.isEmpty {
        let total = log.reduce(0) { $0 + $1.duration }
        Section("Worked on · \(Duration.seconds(total).formatted(.units(width: .abbreviated))) in 30 days") {
          ForEach(Array(log.prefix(20).enumerated()), id: \.offset) { _, piece in
            WorkLogRow(piece: piece)
          }
        }
      }
      Section("History") {
        ForEach(Array(model.history(for: loop).enumerated()), id: \.offset) { _, event in
          LabeledContent(event.change.label) {
            Text(event.at, format: .dateTime.day().month().hour().minute())
          }
        }
        ForEach(Array(sessions.enumerated()), id: \.offset) { _, session in
          LabeledContent("Focused") {
            Text(session.start, format: .dateTime.day().month().hour().minute())
            if session.end != nil {
              Text("· \(Duration.seconds(session.duration).formatted(.units(width: .abbreviated)))")
            } else {
              Text("· now")
            }
          }
        }
      }
    }
    .formStyle(.grouped)
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
    }
  }
}

private struct PeopleSection: View {
  let model: AppModel
  let loop: Loop
  @State private var newName = ""

  var body: some View {
    Section("People") {
      ForEach(model.involvements(of: loop), id: \.person.id) { involvement in
        HStack {
          Text(involvement.person.name)
          Spacer()
          Picker(
            "Direction",
            selection: Binding(
              get: { involvement.direction },
              set: { model.setDirection($0, of: involvement.person, in: loop) }
            )
          ) {
            ForEach(Direction.allCases, id: \.self) { Text($0.label).help($0.help).tag($0) }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          .fixedSize()
          Button("Remove", systemImage: "minus.circle") { model.remove(involvement.person, from: loop) }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
      }
      TextField("Add a Person…", text: $newName)
        .onSubmit {
          model.involve(named: newName, in: loop)
          newName = ""
        }
    }
  }
}

extension LoopChange {
  var label: String {
    switch self {
    case .captured: "Captured"
    case .closed: "Closed"
    case .dropped: "Dropped"
    case .reopened: "Reopened"
    }
  }
}

/// Settings: currently the panel hotkey.
struct SettingsView: View {
  let model: AppModel

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
    }
    .formStyle(.grouped)
    .frame(width: 460)
    .padding()
  }
}
