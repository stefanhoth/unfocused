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

  /// Opens the panel to search and Capture, with whatever was in front of the user as context.
  func show() {
    context = ContextReader.read(NSWorkspace.shared.frontmostApplication)
    present(.search)
  }

  private var context: CaptureContext?

  /// Opens the panel only to ask where the user left off on `loop`.
  func askWhereILeftOff(_ loop: Loop) {
    present(.leftOff(loop))
  }

  func hide() {
    panel?.orderOut(nil)
  }

  private func present(_ mode: PanelMode) {
    model.refresh()
    let panel = panel ?? makePanel()
    self.panel = panel
    // A fresh view each time, so the panel always starts clean.
    panel.contentView = NSHostingView(
      rootView: PanelView(
        model: model,
        context: mode == .search ? context : nil,
        initialMode: mode,
        dismiss: { [weak self] in self?.hide() }
      )
    )
    panel.center()
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate()
  }

  private func makePanel() -> FloatingPanel {
    let panel = FloatingPanel(
      contentRect: NSRect(x: 0, y: 0, width: 640, height: 380),
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

enum PanelMode: Equatable {
  /// Search Open Loops, Focus one, or Capture a new one.
  case search
  /// Ask for an optional Where I left off for a Loop the user just left.
  case leftOff(Loop)
}

struct PanelView: View {
  let model: AppModel
  let context: CaptureContext?
  let dismiss: () -> Void

  @State private var mode: PanelMode
  @State private var text = ""
  @State private var selection = 0
  /// Direction per mentioned name; unmentioned names default to Owed.
  @State private var directions: [String: Direction] = [:]
  @FocusState private var fieldFocused: Bool

  init(model: AppModel, context: CaptureContext?, initialMode: PanelMode, dismiss: @escaping () -> Void) {
    self.model = model
    self.context = context
    self.dismiss = dismiss
    _mode = State(initialValue: initialMode)
  }

  /// The `@word` being typed at the end of the field, if any.
  private var mentionQuery: String? {
    guard let last = text.split(separator: " ", omittingEmptySubsequences: false).last, last.hasPrefix("@") else {
      return nil
    }
    return String(last.dropFirst())
  }

  private var suggestions: [Person] {
    guard let query = mentionQuery else { return [] }
    return Array(model.searchPeople(query).prefix(6))
  }

  private var mentioned: [String] { model.mentionedNames(in: text) }

  /// Search results, without the Focused Loop when nothing is typed (it has its own section).
  private var results: [Loop] {
    let matches = model.search(text)
    let shown = text.isEmpty ? matches.filter { $0.id != model.focusedLoop?.id } : matches
    return Array(shown.prefix(8))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      switch mode {
      case .search: searchContent
      case .leftOff(let loop): leftOffContent(loop)
      }
    }
    .frame(width: 640, height: 380)
    .background(.regularMaterial)
    .onAppear { fieldFocused = true }
  }

  // MARK: Search

  @ViewBuilder private var searchContent: some View {
    inputField("Search your Loops, or type something new…")
      .onChange(of: text) { selection = 0 }
      .onKeyPress(.return, phases: .down) { press in
        if press.modifiers.contains(.command) {
          captureTyped()
        } else if !suggestions.isEmpty {
          completeMention()
        } else {
          focusSelected()
        }
        return .handled
      }
      .onKeyPress(.tab) {
        if !suggestions.isEmpty {
          completeMention()
        } else if let context, text.isEmpty {
          text = context.anchor.title
        } else if let last = mentioned.last {
          directions[last] = (directions[last] ?? .owed).toggled
        } else {
          return .ignored
        }
        return .handled
      }
      .onKeyPress(characters: ["k", "d"], phases: .down) { press in
        guard press.modifiers.contains(.command), results.indices.contains(selection) else { return .ignored }
        let loop = results[selection]
        let left = press.characters == "k" ? model.close(loop) : model.drop(loop)
        if let left { askWhereILeftOff(left) }
        selection = min(selection, max(results.count - 1, 0))
        return .handled
      }
      .onKeyPress(.downArrow) {
        let count = suggestions.isEmpty ? results.count : suggestions.count
        selection = min(selection + 1, max(count - 1, 0))
        return .handled
      }
      .onKeyPress(.upArrow) {
        selection = max(selection - 1, 0)
        return .handled
      }

    if let context {
      contextLine(context)
    }

    if !mentioned.isEmpty {
      mentionChips
    }

    Divider()

    if !suggestions.isEmpty {
      VStack(alignment: .leading, spacing: 2) {
        ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, person in
          Label(person.name, systemImage: "person")
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
      Spacer(minLength: 0)
      hints(["↩ or ⇥ Add Person", "esc Hide"])
    } else {
      searchResults
    }
  }

  @ViewBuilder private var searchResults: some View {
    if text.isEmpty, let focused = model.focusedLoop {
      VStack(alignment: .leading, spacing: 4) {
        Label("Focused", systemImage: "scope").font(.caption).foregroundStyle(.secondary)
        Text(focused.title).font(.headline)
        if let note = focused.whereILeftOff {
          Text("Where I left off: \(note)").foregroundStyle(.secondary)
        }
      }
      .padding(16)
      Divider()
    }

    if results.isEmpty {
      Text(emptyHint)
        .foregroundStyle(.secondary)
        .padding(16)
    } else {
      VStack(alignment: .leading, spacing: 2) {
        ForEach(Array(results.enumerated()), id: \.element.id) { index, loop in
          HStack {
            Text(loop.title).lineLimit(1)
            Spacer()
            if loop.id == model.focusedLoop?.id {
              Image(systemName: "scope").foregroundStyle(.secondary)
            }
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(
            index == selection ? Color.accentColor.opacity(0.2) : .clear,
            in: RoundedRectangle(cornerRadius: 6)
          )
        }
      }
      .padding(8)
    }

    Spacer(minLength: 0)
    hints(["↩ Focus", "⌘↩ Capture new", "⌘K Close", "⌘D Drop", "@ Person", "esc Hide"])
  }

  private var mentionChips: some View {
    HStack(spacing: 8) {
      ForEach(mentioned, id: \.self) { name in
        let direction = directions[name] ?? .owed
        Label("\(name) · \(direction.label)", systemImage: direction == .owed ? "arrow.left" : "arrow.right")
          .font(.caption)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(.quaternary, in: Capsule())
          .help(direction.help)
      }
      Text("⇥ switches Owed/Waiting").font(.caption2).foregroundStyle(.tertiary)
      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 10)
  }

  private func completeMention() {
    guard suggestions.indices.contains(selection), let query = mentionQuery else { return }
    text = String(text.dropLast(query.count + 1)) + "@\(suggestions[selection].name) "
    selection = 0
  }

  private var emptyHint: String {
    if !text.isEmpty { return "No matching Loop. ⌘↩ captures it." }
    if context != nil { return "⌘↩ captures what's in front of you." }
    return "No other Open Loops."
  }

  private func focusSelected() {
    guard results.indices.contains(selection) else { return }
    if let left = model.focus(results[selection]) {
      askWhereILeftOff(left)
    } else {
      dismiss()
    }
  }

  private func captureTyped() {
    guard let loop = model.capture(title: text, anchor: context?.anchor, directions: directions) else { return }
    // The user is already where the new Loop lives; don't reopen it.
    if let left = model.focus(loop, openAnchors: false) {
      askWhereILeftOff(left)
    } else {
      dismiss()
    }
  }

  private func askWhereILeftOff(_ loop: Loop) {
    text = ""
    mode = .leftOff(loop)
    fieldFocused = true
  }

  private func contextLine(_ context: CaptureContext) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Label {
        Text(context.anchor.title).lineLimit(1)
      } icon: {
        Image(systemName: "link")
      }
      .font(.callout)
      .foregroundStyle(.secondary)
      .help("⌘↩ captures with this as its Anchor; ⇥ copies the title into the field")
      if context.missingAccessibility {
        HStack {
          Text("Allow Accessibility so unfocused can see window titles.")
          Button("Allow…") { Permissions.requestAccessibility() }
            .buttonStyle(.link)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 10)
  }

  // MARK: Where I left off

  @ViewBuilder private func leftOffContent(_ loop: Loop) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Where did you leave off?").font(.caption).foregroundStyle(.secondary)
      Text(loop.title).font(.headline)
    }
    .padding([.horizontal, .top], 16)

    inputField(loop.whereILeftOff ?? "One line to get back in quickly (optional)")
      .onKeyPress(.return) {
        model.setWhereILeftOff(loop, to: text)
        dismiss()
        return .handled
      }

    Spacer(minLength: 0)
    hints(["↩ Save", "esc Skip"])
  }

  // MARK: Shared

  private func inputField(_ prompt: String) -> some View {
    TextField(prompt, text: $text)
      .textFieldStyle(.plain)
      .font(.title2)
      .padding(16)
      .focused($fieldFocused)
      .onKeyPress(.escape) {
        dismiss()
        return .handled
      }
  }

  private func hints(_ items: [String]) -> some View {
    HStack(spacing: 16) {
      ForEach(items, id: \.self) { Text($0) }
      Spacer()
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }
}
