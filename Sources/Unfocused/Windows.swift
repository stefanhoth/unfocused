import SwiftUI
import UnfocusedCore

/// The full window listing Open Loops.
struct LoopsWindow: View {
  let model: AppModel

  var body: some View {
    Group {
      if model.openLoops.isEmpty {
        ContentUnavailableView(
          "No Open Loops",
          systemImage: "circle.dashed",
          description: Text("Press \(model.hotKey.label) anywhere to capture one.")
        )
      } else {
        List(model.openLoops) { loop in
          VStack(alignment: .leading, spacing: 2) {
            Text(loop.title)
            Text(loop.capturedAt, format: .relative(presentation: .named))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 2)
        }
      }
    }
    .frame(minWidth: 420, minHeight: 320)
    .navigationTitle("Open Loops")
    .onAppear { model.refresh() }
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
    }
    .formStyle(.grouped)
    .frame(width: 420)
    .padding()
  }
}
