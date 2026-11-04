import AppKit
import SwiftUI

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

      VStack(alignment: .leading, spacing: 2) {
        Text("What an Agent asks for is sent to the app that calls unfocused.")
        Text("With a remote model, that app passes it on to the provider's servers.")
        Text("With a local model, it stays on this Mac.")
        Text("unfocused itself sends nothing anywhere.")
      }
      Text(
        "This switch is your consent, not a lock. Any program running as you can read unfocused's data file directly. The switch makes sure unfocused itself only shares what you agreed to."
      )
      .font(.caption)
      .foregroundStyle(.secondary)

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
