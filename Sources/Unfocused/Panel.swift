import AppKit
import SwiftUI
import UnfocusedCore

/// The floating, keyboard-only panel opened by the hotkey.
@MainActor
final class PanelController {
  private let model: AppModel
  private var panel: FloatingPanel?

  init(model: AppModel) {
    self.model = model
  }

  var isVisible: Bool { panel?.isVisible == true }

  func toggle() {
    isVisible ? hide() : show()
  }

  func show() {
    let panel = panel ?? makePanel()
    self.panel = panel
    // A fresh view each time, so the query starts empty.
    panel.contentView = NSHostingView(rootView: PanelView(model: model, dismiss: { [weak self] in self?.hide() }))
    panel.center()
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate()
  }

  func hide() {
    panel?.orderOut(nil)
  }

  private func makePanel() -> FloatingPanel {
    let panel = FloatingPanel(
      contentRect: NSRect(x: 0, y: 0, width: 640, height: 360),
      styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isMovableByWindowBackground = true
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.onResignKey = { [weak self] in self?.hide() }
    return panel
  }
}

final class FloatingPanel: NSPanel {
  var onResignKey: (() -> Void)?

  override var canBecomeKey: Bool { true }

  override func resignKey() {
    super.resignKey()
    onResignKey?()
  }
}

/// Search Open Loops; ⌘Enter Captures what was typed.
struct PanelView: View {
  let model: AppModel
  let dismiss: () -> Void

  @State private var query = ""
  @State private var selection = 0
  @FocusState private var fieldFocused: Bool

  private var results: [UnfocusedLoopRow] {
    model.search(query).prefix(8).map(UnfocusedLoopRow.init)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      TextField("Search your Loops, or type something new…", text: $query)
        .textFieldStyle(.plain)
        .font(.title2)
        .padding(16)
        .focused($fieldFocused)
        .onChange(of: query) { selection = 0 }
        .onKeyPress(.return, phases: .down) { press in
          guard press.modifiers.contains(.command) else { return .ignored }
          if model.capture(title: query) != nil { dismiss() }
          return .handled
        }
        .onKeyPress(.downArrow) {
          selection = min(selection + 1, max(results.count - 1, 0))
          return .handled
        }
        .onKeyPress(.upArrow) {
          selection = max(selection - 1, 0)
          return .handled
        }
        .onKeyPress(.escape) {
          dismiss()
          return .handled
        }

      Divider()

      if results.isEmpty {
        Text(query.isEmpty ? "No Open Loops yet." : "No matching Loop.")
          .foregroundStyle(.secondary)
          .padding(16)
      } else {
        VStack(alignment: .leading, spacing: 2) {
          ForEach(Array(results.enumerated()), id: \.element.id) { index, row in
            Text(row.title)
              .lineLimit(1)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                index == selection ? Color.accentColor.opacity(0.2) : .clear,
                in: RoundedRectangle(cornerRadius: 6)
              )
          }
        }
        .padding(8)
      }

      Spacer(minLength: 0)

      HStack {
        Text("⌘↩ Capture as new Loop")
        Spacer()
        Text("esc Close")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
    }
    .frame(width: 640, height: 360)
    .background(.regularMaterial)
    .onAppear { fieldFocused = true }
  }
}

struct UnfocusedLoopRow: Identifiable {
  let id: UUID
  let title: String
}

extension UnfocusedLoopRow {
  init(_ loop: UnfocusedCore.Loop) {
    self.init(id: loop.id, title: loop.title)
  }
}
