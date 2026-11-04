import AppKit
import SwiftUI
import UnfocusedCore

/// Settings → Agent access (DESIGN.md "Settings: Agent access", ADR 0007): the consent switch, where
/// the data goes, and the setup command. Nothing is shared until the user turns the switch on.
struct AgentAccessSection: View {
  let model: AppModel

  static let setupCommand = "claude mcp add unfocused -- unfocused-mcp"

  @State private var copied = false

  var body: some View {
    Section("Agent access") {
      Text(
        "Let an app you chose read your Loops, for example Claude or a local model. It can only read. It can't change anything."
      )
      .font(.callout)

      let isOn = model.agentAccessLoops
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Toggle(
            "Let Agents read my Loops",
            isOn: Binding(get: { model.agentAccessLoops }, set: { model.agentAccessLoops = $0 })
          )
          .toggleStyle(.switch)
          .tint(Style.brand)
          Text(isOn ? "On" : "Off")
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
        Text("Takes effect on the next request.").font(.caption).foregroundStyle(.secondary)
      }

      // Activity depends on Loops: disabled and Off while Loops is off, and the user's own choice
      // returns when Loops is turned on again (DESIGN.md "Settings: Agent access").
      let activityOn = isOn && model.agentAccessActivity
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Toggle(
            "Let Agents read my Activity",
            isOn: Binding(get: { activityOn }, set: { model.agentAccessActivity = $0 })
          )
          .toggleStyle(.switch)
          .tint(Style.brand)
          .disabled(!isOn)
          Text(activityOn ? "On" : "Off")
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
        Text(
          isOn
            ? "Window titles, pages and conversations you were in, and your time."
            : "Turn on Loops first. Activity is shared in addition to Loops."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Where answers go")
          .font(.subheadline.weight(.semibold))
        flowRow("arrow.right.circle", "To the app that calls unfocused.")
        flowRow("cloud", "With a remote model, that app passes them on to the provider's servers.")
        flowRow("laptopcomputer", "With a local model, they stay on this Mac.")
        flowRow("lock", "unfocused itself sends nothing anywhere.")
      }
      Text(
        "This switch is your consent, not a lock. Any program running as you can read unfocused's data file directly. The switch makes sure unfocused itself only shares what you agreed to."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)

      HStack {
        Text(Self.setupCommand)
          .font(.body.monospaced())
          .textSelection(.enabled)
        Spacer()
        Button(copied ? "Copied" : "Copy") { copy() }
          .accessibilityLabel(copied ? "Copied" : "Copy setup command")
      }
      .padding(10)
      .background { Style.rowBackground(selected: false).clipShape(RoundedRectangle(cornerRadius: 10)) }
      Text("Other apps: use `unfocused-mcp` as the command. It needs no macOS permission.")
        .font(.caption)
        .foregroundStyle(.secondary)
      LastUsedLine()
    }
  }

  private func flowRow(_ symbol: String, _ text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(systemName: symbol)
        .frame(width: 18)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text(text)
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func copy() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(Self.setupCommand, forType: .string)
    copied = true
    Task {
      try? await Task.sleep(for: .seconds(2))
      copied = false
    }
  }
}

/// "Last used by Claude at 14:32" (DESIGN.md "Settings: Agent access"). `unfocused-mcp` can't write to
/// the database it reads, so it leaves its last call in a small file next to the logs
/// (docs/DECISIONS.md, 2026-11-04); this polls that file while Settings is open.
private struct LastUsedLine: View {
  @State private var last: AgentCall?
  private let store = AgentCallStore(directory: AppEnvironment.logsDirectory)

  var body: some View {
    Text(Self.text(for: last))
      .font(.caption)
      .foregroundStyle(.secondary)
      .task {
        while !Task.isCancelled {
          last = store.last()
          try? await Task.sleep(for: .seconds(2))
        }
      }
  }

  static func text(for call: AgentCall?, now: Date = Date()) -> String {
    guard let call else { return "Not used yet." }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    let today = Calendar.current.isDate(call.date, inSameDayAs: now)
    formatter.dateFormat = today ? "HH:mm" : "MMM d, HH:mm"
    let when = formatter.string(from: call.date)
    return "Last used by \(call.agent) at \(when)" + (call.refused ? " \(AgentCall.refusedNote)" : "")
  }
}
