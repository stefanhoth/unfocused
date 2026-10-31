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

  /// Opens the panel to ask what to do with a Focus that sleep, idle or a lock interrupted.
  func askAboutInterruption(_ interruption: FocusInterruption) {
    present(.welcomeBack(interruption))
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
    NSApp.activate()
    panel.makeKeyAndOrderFront(nil)
    // On a panel's first showing, SwiftUI's focus request arrives before the window can take it.
    // Once SwiftUI has laid the view out, put the cursor in the text field directly.
    DispatchQueue.main.async { [weak panel] in
      guard let panel else { return }
      panel.makeKey()
      if let field = Self.firstTextField(in: panel.contentView) { panel.makeFirstResponder(field) }
    }
  }

  private static func firstTextField(in view: NSView?) -> NSTextField? {
    guard let view else { return nil }
    if let field = view as? NSTextField, field.isEditable { return field }
    for subview in view.subviews {
      if let field = firstTextField(in: subview) { return field }
    }
    return nil
  }

  private func makePanel() -> FloatingPanel {
    let panel = FloatingPanel(
      contentRect: NSRect(x: 0, y: 0, width: 640, height: 380),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    // The SwiftUI view draws the glass; the window itself is invisible.
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
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

extension RelatedReason {
  var label: String {
    switch self {
    case .samePerson(let name): "with \(name)"
    case .similarTitle: "similar title"
    case .sameSource: "same place"
    case .similarMeaning: "similar meaning"
    }
  }
}

enum PanelMode: Equatable {
  /// Search Open Loops, Focus one, or Capture a new one.
  case search
  /// Ask for an optional Where I left off for a Loop the user just left.
  case leftOff(Loop)
  /// Back after an interrupted Focus: Continue, Close, Drop or Unfocus.
  case welcomeBack(FocusInterruption)
}

struct PanelView: View {
  let model: AppModel
  let context: CaptureContext?
  let dismiss: () -> Void

  @State private var mode: PanelMode
  @State private var text = ""
  /// The highlighted row; -1 means none, the text field itself (↑ past the first row).
  @State private var selection = 0
  /// Direction per mentioned name; unmentioned names default to Owed.
  @State private var directions: [String: Direction] = [:]
  /// Related Loops including matches by meaning, once the Reasoner has answered for `text`.
  @State private var reasonedRelated: (text: String, loops: [RelatedLoop])?
  /// The Reasoner's title for the context, filled in with ⇥.
  @State private var suggestedTitle: String?
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

  /// Open Loops related to the new title, offered as "add to this Loop instead".
  private var related: [RelatedLoop] {
    guard mentionQuery == nil else { return [] }
    if let reasonedRelated, reasonedRelated.text == text { return reasonedRelated.loops }
    return model.relatedLoops(toCapture: text, anchor: context?.anchor)
  }

  /// The Loop that already has what's in front of the user as an Anchor.
  private var existingLoop: Loop? {
    context.flatMap { model.loop(anchoredAt: $0.anchor) }
  }

  /// Search results. With nothing typed: the existing Loop for this context first, then the top 3
  /// Loose Ends, and the Focused Loop left out (it has its own section).
  private var results: [Loop] {
    var shown = model.search(text)
    if text.isEmpty {
      shown.removeAll { $0.id == model.focusedLoop?.id }
      let looseEnds = model.looseEnds.map(\.loop).filter { $0.id != model.focusedLoop?.id }.prefix(3)
      shown.removeAll { loop in looseEnds.contains { $0.id == loop.id } }
      shown.insert(contentsOf: looseEnds, at: 0)
      if let existing = existingLoop, existing.state == .open {
        shown.removeAll { $0.id == existing.id }
        shown.insert(existing, at: 0)
      }
    }
    return Array(shown.prefix(text.isEmpty ? 8 : 4))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      switch mode {
      case .search: searchContent
      case .leftOff(let loop): leftOffContent(loop)
      case .welcomeBack(let interruption): welcomeBackContent(interruption)
      }
    }
    .frame(width: 640, height: 380)
    .calmGlass(cornerRadius: Style.panelRadius)
    // The view appears before its borderless panel is the key window, and SwiftUI drops a focus
    // request made then. Ask again once the panel has become key.
    .onAppear { fieldFocused = true }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
      if note.object is FloatingPanel { fieldFocused = true }
    }
    .task {
      if let context { suggestedTitle = await model.captureTitle(for: context.anchor) }
    }
    .task(id: text) {
      guard !text.isEmpty else { return }
      // Wait for a pause in typing before asking the on-device model.
      try? await Task.sleep(for: .milliseconds(400))
      guard !Task.isCancelled else { return }
      let typed = text
      let loops = await model.relatedLoopsByMeaning(toCapture: typed, anchor: context?.anchor)
      if !Task.isCancelled { reasonedRelated = (typed, loops) }
    }
  }

  // MARK: Search

  @ViewBuilder private var searchContent: some View {
    inputField("Search your Loops, or type something new…", systemImage: "magnifyingglass")
      .onChange(of: text) { selection = 0 }
      .onKeyPress(.return, phases: .down) { press in
        if press.modifiers.contains(.option) {
          addContextToSelected()
        } else if press.modifiers.contains(.command) {
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
          text = suggestedTitle ?? context.anchor.title
        } else if let last = mentioned.last {
          directions[last] = (directions[last] ?? .owed).toggled
        } else {
          return .ignored
        }
        return .handled
      }
      .onKeyPress(characters: ["r"], phases: .down) { press in
        guard press.modifiers.contains(.command), let existing = existingLoop, existing.state != .open else {
          return .ignored
        }
        model.reopen(existing)
        if let left = model.focus(existing, openAnchors: false) { askWhereILeftOff(left) } else { dismiss() }
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
      .onKeyPress(characters: ["u"], phases: .down) { press in
        guard press.modifiers.contains(.command), model.focusedLoop != nil else { return .ignored }
        if let left = model.unfocus() { askWhereILeftOff(left) } else { dismiss() }
        return .handled
      }
      .onKeyPress(characters: ["1", "2", "3"], phases: .down) { press in
        guard press.modifiers.contains(.command), let digit = Int(press.characters), related.indices.contains(digit - 1)
        else { return .ignored }
        addToRelated(related[digit - 1].loop)
        return .handled
      }
      .onKeyPress(.downArrow) {
        let count = suggestions.isEmpty ? results.count : suggestions.count
        selection = min(selection + 1, max(count - 1, 0))
        return .handled
      }
      .onKeyPress(.upArrow) {
        selection = max(selection - 1, -1)
        return .handled
      }

    if let context {
      contextLine(context)
    }

    if let existing = existingLoop, text.isEmpty {
      existingLoopNote(existing)
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
            .background(Style.rowBackground(selected: index == selection))
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
        HStack {
          Label("Focused", systemImage: "scope").font(.caption).foregroundStyle(.secondary)
          Spacer()
          Text("⌘U Unfocus").font(.caption).foregroundStyle(.tertiary)
        }
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
            AgingMark(aging: model.aging[loop.id])
            VStack(alignment: .leading, spacing: 1) {
              Text(loop.title).lineLimit(1)
              LooseEndNote(aging: model.aging[loop.id])
            }
            Spacer()
            if loop.id == model.focusedLoop?.id {
              Image(systemName: "scope").foregroundStyle(.secondary)
            }
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Style.rowBackground(selected: index == selection))
        }
      }
      .padding(8)
    }

    if !text.isEmpty {
      captureNudges
    }

    Spacer(minLength: 0)
    hints(
      context == nil
        ? ["↩ Focus", "⌘↩ Capture new", "⌘K Close", "⌘D Drop", "@ Person", "esc Hide"]
        : ["↩ Focus", "⌘↩ Capture new", "⌥↩ Add here as Anchor", "⌘K Close", "⌘D Drop", "esc Hide"]
    )
  }

  /// Related Loops to add to instead, and a gentle note about Loose Ends. Capture still works.
  @ViewBuilder private var captureNudges: some View {
    let related = related
    if !related.isEmpty {
      Divider()
      VStack(alignment: .leading, spacing: 4) {
        Text("Add to an existing Loop instead?").font(.caption).foregroundStyle(.secondary)
        ForEach(Array(related.enumerated()), id: \.element.loop.id) { index, item in
          HStack {
            Text("⌘\(index + 1)").font(.caption.monospaced()).foregroundStyle(.secondary)
            Text(item.loop.title).lineLimit(1)
            Text(item.reasons.map(\.label).joined(separator: " · ")).font(.caption).foregroundStyle(.tertiary)
            Spacer()
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }
    if let looseEnds = model.looseEndsOlderThanNewIdea() {
      Label("\(looseEnds) Loose Ends are older than this idea.", systemImage: "hourglass")
        .font(.caption)
        .foregroundStyle(.orange)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
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

  private func existingLoopNote(_ loop: Loop) -> some View {
    Label {
      if loop.state == .open {
        Text("This already has a Loop: “\(loop.title)”. ↩ Focuses it.")
      } else {
        Text("This was a Loop you \(loop.state.label.lowercased()): “\(loop.title)”. ⌘R reopens it.")
      }
    } icon: {
      Image(systemName: "arrow.uturn.backward.circle")
    }
    .font(.callout)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 16)
    .padding(.bottom, 10)
  }

  /// Adds what's in front of the user as an Anchor to the selected Loop, then Focuses it.
  private func addContextToSelected() {
    guard let context, results.indices.contains(selection) else { return }
    let loop = results[selection]
    model.addAnchor(context.anchor, to: loop)
    if let left = model.focus(loop, openAnchors: false) { askWhereILeftOff(left) } else { dismiss() }
  }

  private func addToRelated(_ loop: Loop) {
    model.add(to: loop, anchor: context?.anchor, mentionsIn: text, directions: directions)
    if let left = model.focus(loop, openAnchors: false) { askWhereILeftOff(left) } else { dismiss() }
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
    // Back in the text field (↑ past the first row): ↩ captures what was typed.
    if selection == -1 {
      if !text.trimmingCharacters(in: .whitespaces).isEmpty { captureTyped() }
      return
    }
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

  // MARK: Welcome back

  @ViewBuilder private func welcomeBackContent(_ interruption: FocusInterruption) -> some View {
    let loop = interruption.loop
    VStack(alignment: .leading, spacing: 6) {
      Text("Welcome back").font(.caption).foregroundStyle(.secondary)
      Text(loop.title).font(.title2)
      Text(
        interruption.reason == .sleep
          ? "Focus ended when your Mac went to sleep."
          : "Focus paused while you were away. That time doesn't count."
      )
      .foregroundStyle(.secondary)
      if let note = loop.whereILeftOff {
        Label(note, systemImage: "bookmark").foregroundStyle(.secondary).lineLimit(2)
      }
    }
    .padding(16)

    HStack {
      Button("Continue") {
        model.continueInterruptedFocus()
        dismiss()
      }
      .keyboardShortcut(.defaultAction)
      Button("Close") {
        model.close(loop)
        dismiss()
      }
      .keyboardShortcut("k", modifiers: .command)
      Button("Drop") {
        model.drop(loop)
        dismiss()
      }
      .keyboardShortcut("d", modifiers: .command)
      Button("Unfocus") {
        model.dismissInterruptedFocus()
        askWhereILeftOff(loop)
      }
      .keyboardShortcut("u", modifiers: .command)
      Spacer()
      Button("Later", action: dismiss).keyboardShortcut(.cancelAction)
    }
    .padding(.horizontal, 16)

    Spacer(minLength: 0)
    hints(["↩ Continue", "⌘K Close", "⌘D Drop", "⌘U Unfocus", "esc Ask me later"])
  }

  // MARK: Shared

  /// The text field stays the outermost view so key handlers attached by callers (arrows, ↩, ⇥)
  /// run before the field editor uses the keys itself; the icon is an overlay.
  private func inputField(_ prompt: String, systemImage: String? = nil) -> some View {
    TextField(prompt, text: $text)
      .textFieldStyle(.plain)
      .font(.system(size: 22))
      .focused($fieldFocused)
      .padding(.leading, systemImage == nil ? 0 : 30)
      .overlay(alignment: .leading) {
        if let systemImage {
          Image(systemName: systemImage).font(.system(size: 18, weight: .medium)).foregroundStyle(.secondary)
        }
      }
      .padding(18)
      .onKeyPress(.escape) {
        dismiss()
        return .handled
      }
  }

  private func hints(_ items: [String]) -> some View {
    KeyHints(items: items)
  }

}
