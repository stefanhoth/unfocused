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
  /// Opens the panel only to ask where the user left off on `loop`; afterwards, opens the Anchors
  /// of `openAnchorsAfter` (the Loop just Focused), if any.
  func askWhereILeftOff(_ loop: Loop, openAnchorsAfter: Loop? = nil) {
    present(.leftOff(loop, openAnchorsAfter: openAnchorsAfter))
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
        dismiss: { [weak self] in self?.hide() },
        focusField: { [weak self] in self?.focusFieldSoon() },
        askWhereILeftOff: { [weak self] loop, after in self?.askWhereILeftOff(loop, openAnchorsAfter: after) }
      )
    )
    panel.center()
    NSApp.activate()
    panel.makeKeyAndOrderFront(nil)
    // On a panel's first showing, SwiftUI's focus request arrives before the window can take it.
    // Once SwiftUI has laid the view out, put the cursor in the text field directly.
    focusFieldSoon()
  }

  /// Makes the panel key and puts the cursor in its text field after SwiftUI's next layout pass.
  /// Uses the panel itself: `NSApp.keyWindow` is often nil for a non-activating panel.
  func focusFieldSoon() {
    for delay in [0.0, 0.05, 0.3] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
        guard let self, let panel = self.panel, panel.isVisible else { return }
        panel.makeKey()
        Self.focusTextField(in: panel)
        if delay == 0.3, Self.firstTextField(in: panel.contentView) != nil {
          // Checked on every showing; the release checklist relies on this line.
          let editing = panel.isKeyWindow && panel.firstResponder is NSTextView
          self.model.log.info("Panel text field has the cursor: \(editing)")
        }
      }
    }
  }

  /// Puts the cursor in the window's first editable text field, if it has one.
  static func focusTextField(in window: NSWindow?) {
    guard let window, let field = firstTextField(in: window.contentView) else { return }
    window.makeFirstResponder(field)
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
      contentRect: NSRect(
        x: 0,
        y: 0,
        width: Style.panelSize.width + 2 * Style.glowMargin,
        height: Style.panelSize.height + 2 * Style.glowMargin
      ),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    // The SwiftUI view draws the glass; the window itself is invisible.
    panel.isOpaque = false
    panel.backgroundColor = .clear
    // No system shadow: macOS draws it from the window's rectangle, which showed as a square around
    // the rounded glass. The view draws its own shadow and glow in a transparent margin instead.
    panel.hasShadow = false
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
  case leftOff(Loop, openAnchorsAfter: Loop?)
  /// Back after an interrupted Focus: Continue, Close Loop, Let go or Unfocus.
  case welcomeBack(FocusInterruption)
}

struct PanelView: View {
  let model: AppModel
  let context: CaptureContext?
  let dismiss: () -> Void
  /// Puts the cursor in the panel's text field once SwiftUI has laid out the current mode.
  let focusField: () -> Void
  /// Shows Where I left off for a Loop in a fresh panel; the second Loop's Anchors open afterwards.
  let showLeftOff: (Loop, Loop?) -> Void

  @State private var mode: PanelMode
  @State private var text = ""
  /// The highlighted row; -1 means none, the text field itself (↑ past the first row), where ↩ does
  /// nothing.
  /// Opens with nothing selected: the cursor is in the text field until ↓ (or typing) picks a row.
  @State private var selection = -1
  /// While Focused: true once the user stepped from the Focused Loop into the list (↓).
  @State private var browsing = false
  /// A short confirmation after Close Loop or Let go, with ⌘Z to undo.
  @State private var confirmation: Confirmation?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  /// The Loop just Focused, whose Anchors open once Where I left off is answered or skipped.
  @State private var anchorsToOpenAfterLeftOff: Loop?
  /// Direction per mentioned name; unmentioned names default to Owed.
  @State private var directions: [String: Direction] = [:]
  /// Related Loops including matches by meaning, once the Reasoner has answered for `text`.
  @State private var reasonedRelated: (text: String, loops: [RelatedLoop])?
  /// The Reasoner's title for the context, filled in with ⇥.
  @State private var suggestedTitle: String?
  @FocusState private var fieldFocused: Bool

  init(
    model: AppModel,
    context: CaptureContext?,
    initialMode: PanelMode,
    dismiss: @escaping () -> Void,
    focusField: @escaping () -> Void = {},
    askWhereILeftOff: @escaping (Loop, Loop?) -> Void = { _, _ in }
  ) {
    self.model = model
    self.context = context
    self.dismiss = dismiss
    self.focusField = focusField
    self.showLeftOff = askWhereILeftOff
    _mode = State(initialValue: initialMode)
    if case .leftOff(_, let after) = initialMode { _anchorsToOpenAfterLeftOff = State(initialValue: after) }
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
      case .leftOff(let loop, _): leftOffContent(loop)
      case .welcomeBack(let interruption): welcomeBackContent(interruption)
      }
    }
    .animation(reduceMotion ? .easeInOut(duration: 0.15) : .snappy, value: isHero)
    .tint(Style.brand)
    .overlay(alignment: .bottom) {
      if let confirmation {
        ConfirmationBar(confirmation: confirmation)
          .padding(.bottom, 56)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .frame(width: Style.panelSize.width, height: Style.panelSize.height)
    .calmGlass(cornerRadius: Style.panelRadius)
    .overlay(GradientGlow(cornerRadius: Style.panelRadius))
    .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
    .padding(Style.glowMargin)
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
    // While Focused, the Focused Loop comes first and the search sits below it; typing or ↓ turns
    // it into the slim strip and the search moves up. The field itself never changes place in the
    // view tree, so the cursor and typing aren't lost.
    if let focused = model.focusedLoop {
      if isHero {
        focusHero(focused)
      } else {
        focusStrip(focused)
      }
    }
    inputField(
      isHero ? "Switch to another Loop…" : "Search your Loops, or type something new…",
      systemImage: "magnifyingglass"
    )
    .onChange(of: text) { selection = text.isEmpty ? -1 : 0 }
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
    // ⌘C Close Loop, ⌘L Let go, matching C and L in the Tie-off. With no Loop to act on, ⌘C copies
    // as usual. (⌘⌫ can't be used: the text field takes it for itself.)
    .onKeyPress(characters: ["c", "l"], phases: .down) { press in
      guard press.modifiers.contains(.command) else { return .ignored }
      guard let loop = actionLoop else {
        // ⌘C copies text as usual; ⌘L with nothing selected explains instead of doing nothing.
        guard press.characters == "l" else { return .ignored }
        confirm(Confirmation(text: "Select a Loop first: ↓", systemImage: "arrow.down", celebrate: false, undo: nil))
        return .handled
      }
      // Letting go of what you chose to Focus on is a bigger step than switching: not from the Focused
      // view, only from the list once it's no longer Focused.
      if press.characters == "l", isHero {
        confirm(
          Confirmation(text: "Unfocus first (⌘U) to let it go", systemImage: "info.circle", celebrate: false, undo: nil)
        )
        return .handled
      }
      finish(loop, close: press.characters == "c")
      return .handled
    }
    .onKeyPress(characters: ["e"], phases: .down) { press in
      guard press.modifiers.contains(.command), let loop = actionLoop else { return .ignored }
      dismiss()
      model.editLoop?(loop)
      return .handled
    }
    .onKeyPress(characters: ["z"], phases: .down) { press in
      guard press.modifiers.contains(.command), let undo = confirmation?.undo else { return .ignored }
      withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .snappy) {
        undo()
        confirmation = nil
      }
      return .handled
    }
    .onKeyPress(characters: ["o"], phases: .down) { press in
      guard press.modifiers.contains(.command), let loop = actionLoop else { return .ignored }
      let anchors = model.anchors(of: loop)
      guard !anchors.isEmpty else { return .ignored }
      anchors.forEach(AnchorOpener.open)
      dismiss()
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
      if isHero {
        browsing = true
        selection = 0
        return .handled
      }
      let count = suggestions.isEmpty ? results.count : suggestions.count
      selection = min(selection + 1, max(count - 1, 0))
      return .handled
    }
    .onKeyPress(.upArrow) {
      // Past the top of the list, back to the Focused Loop.
      if selection == -1, browsing, text.isEmpty, model.focusedLoop != nil { browsing = false }
      selection = max(selection - 1, -1)
      return .handled
    }

    if isHero {
      hints(["↓ Switch", "⌘↩ Capture new", "esc Hide"])
    } else {
      searchBody
    }
  }

  @ViewBuilder private var searchBody: some View {
    if let context {
      contextLine(context)
    }

    // An Open Loop for this spot is marked "You're here" in the list; only a Closed or Let-go one,
    // which isn't listed, needs a line of its own.
    if let existing = existingLoop, existing.state != .open, text.isEmpty {
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
    browseResults
  }

  /// While Focused, the panel is about the Focused Loop; switching is one deliberate step (↓ or
  /// typing) away, so the panel doesn't invite jumping to something else.
  private var isHero: Bool { model.focusedLoop != nil && text.isEmpty && !browsing }

  /// The Loop ⌘C, ⌘L and ⌘O act on: the Focused one in the hero view, otherwise the selected row.
  private var actionLoop: Loop? {
    if isHero { return model.focusedLoop }
    return results.indices.contains(selection) ? results[selection] : nil
  }

  private func focusHero(_ loop: Loop) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        Image(nsImage: MenuBarGlyph.image(focused: true))
          .renderingMode(.template)
          .foregroundStyle(Style.logoLinearGradient)
        Text("Focused").font(.callout.weight(.semibold)).foregroundStyle(Style.logoLinearGradient)
        if let start = model.focusSessions(for: loop).last?.start {
          Text("for \(Self.shortAge(start))").font(.callout).monospacedDigit().foregroundStyle(.secondary)
        }
        Spacer()
        // Unfocus changes your state, not the Loop, so it sits with the state, apart from the
        // Loop's own actions.
        KeyHints.Keycap(key: "⌘U")
        Text("Unfocus").font(.callout).foregroundStyle(.secondary)
      }
      .padding(.horizontal, 22)
      .padding(.top, 22)
      PanelLoopDetail(
        model: model,
        loop: loop,
        prominent: true,
        actions: ["⌘C Close Loop", "⌘O Open Anchors", "⌘E Edit"]
      )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    .transition(.opacity.combined(with: .move(edge: .top)))
  }

  @ViewBuilder private var browseResults: some View {

    if results.isEmpty, !text.trimmingCharacters(in: .whitespaces).isEmpty {
      captureRow
    } else if results.isEmpty {
      Text(emptyHint)
        .foregroundStyle(.secondary)
        .padding(16)
    } else {
      // List on the left, the selected Loop's details on the right: enough to get back into it.
      HStack(alignment: .top, spacing: 0) {
        VStack(alignment: .leading, spacing: 2) {
          ForEach(Array(results.enumerated()), id: \.element.id) { index, loop in
            HStack {
              AgingMark(aging: model.aging[loop.id])
              VStack(alignment: .leading, spacing: 2) {
                Text(loop.title).lineLimit(1)
                LooseEndNote(aging: model.aging[loop.id])
              }
              Spacer()
              if loop.id == existingLoop?.id {
                Text("You're here")
                  .font(.caption2.weight(.medium))
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(Capsule().fill(Color.primary.opacity(0.1)))
                  .foregroundStyle(.secondary)
              }
              if loop.id == model.focusedLoop?.id {
                Image(systemName: "scope").foregroundStyle(.secondary)
              }
              Text(Self.shortAge(model.lastEngagement(of: loop) ?? loop.capturedAt))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Style.rowBackground(selected: index == selection))
          }
        }
        .padding(10)
        .frame(width: Style.panelListWidth)
        Divider()
        if results.indices.contains(selection) {
          PanelLoopDetail(
            model: model,
            loop: results[selection],
            actions: ["↩ Focus", "⌘O Open Anchors", "⌘E Edit", "⌘C Close Loop", "⌘L Let go"]
          )
        } else {
          Text("↓ to pick a Loop and see where you left off").font(.callout).foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .frame(maxHeight: .infinity, alignment: .top)
    }

    if !text.isEmpty {
      captureNudges
    }

    Spacer(minLength: 0)
    hints(
      context == nil
        ? ["↑↓ Choose", "⌘↩ Capture new", "@ Person", "esc Hide"]
        : ["↑↓ Choose", "⌘↩ Capture new", "⌥↩ Add here", "@ Person", "esc Hide"]
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

  /// Nothing matches what was typed: offer to capture it as a new Loop. Capturing stays on ⌘↩, never
  /// plain ↩: that bit of friction is deliberate, so new Loops aren't started by accident.
  private var captureRow: some View {
    HStack(spacing: 10) {
      Image(systemName: "plus.circle.fill").font(.system(size: 20, weight: .medium))
        .foregroundStyle(Style.logoLinearGradient)
      VStack(alignment: .leading, spacing: 2) {
        Text("Capture “\(text.trimmingCharacters(in: .whitespaces))”").lineLimit(1)
        Text("No Loop matches yet").font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      Text("⌘↩").font(.callout.weight(.medium)).foregroundStyle(.secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(RoundedRectangle(cornerRadius: Style.rowRadius).strokeBorder(.quaternary))
    .padding(8)
  }

  /// "now", "5m", "3h", "2d", "3w": how long ago, short enough for a list row.
  static func shortAge(_ date: Date, now: Date = Date()) -> String {
    let seconds = max(0, now.timeIntervalSince(date))
    switch seconds {
    case ..<60: return "now"
    case ..<3600: return "\(Int(seconds / 60))m"
    case ..<86_400: return "\(Int(seconds / 3600))h"
    case ..<(14 * 86_400): return "\(Int(seconds / 86_400))d"
    default: return "\(Int(seconds / (7 * 86_400)))w"
    }
  }

  /// The Focused Loop as a status strip above the search: what you're on, and for how long.
  private func focusStrip(_ loop: Loop) -> some View {
    HStack(spacing: 10) {
      Image(nsImage: MenuBarGlyph.image(focused: true))
        .renderingMode(.template)
        .foregroundStyle(Style.logoLinearGradient)
      Text("Focused").font(.callout.weight(.semibold)).foregroundStyle(Style.logoLinearGradient)
      Text(loop.title).font(.callout.weight(.semibold)).lineLimit(1)
      if let start = model.focusSessions(for: loop).last?.start {
        Text("for \(Self.shortAge(start))").font(.callout).monospacedDigit().foregroundStyle(.secondary)
      }
      Spacer()
      KeyHints.Keycap(key: "⌘U")
      Text("Unfocus").font(.callout).foregroundStyle(.secondary)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 10)
    .background(Style.logoLinearGradient.opacity(0.16))
    .overlay(alignment: .bottom) { Divider().opacity(0.5) }
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
      Text("⇥ switches who's waiting").font(.caption2).foregroundStyle(.tertiary)
      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 10)
  }

  private func existingLoopNote(_ loop: Loop) -> some View {
    Label {
      Text(
        loop.state == .closed
          ? "You closed a Loop here: “\(loop.title)”. ⌘R reopens it."
          : "You let go of a Loop here: “\(loop.title)”. ⌘R reopens it."
      )
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
    // ↩ only ever Focuses an existing Loop. Capturing a new one takes ⌘↩, on purpose: that bit of
    // friction keeps new Loops from being started by accident.
    guard results.indices.contains(selection) else { return }
    let target = results[selection]
    // Opening the new Loop's Anchors brings other apps forward, which hides the panel. So when
    // there's a Loop to leave, ask Where I left off first and open the Anchors afterwards.
    if let left = model.focus(target, openAnchors: false) {
      anchorsToOpenAfterLeftOff = target
      askWhereILeftOff(left)
    } else {
      model.anchors(of: target).forEach(AnchorOpener.open)
      dismiss()
    }
  }

  /// Closes or lets go of `loop`. A Closed or Let-go Loop needs no Where I left off; it's finished or
  /// let go. From the Focused view the panel hides; in the list it stays for the next one.
  private func finish(_ loop: Loop, close: Bool) {
    withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .snappy) {
      if close { model.close(loop) } else { model.letGo(loop) }
      browsing = false
      selection = min(selection, results.count - 1)
    }
    if close { NSSound(named: "Glass")?.play() }
    confirm(
      Confirmation(
        text: close ? "Closed “\(loop.title)”" : "Let go of “\(loop.title)”",
        systemImage: close ? "checkmark.circle.fill" : "arrow.down.circle",
        celebrate: close,
        undo: { [model] in model.reopen(loop) }
      )
    )
  }

  /// Shows `confirmation` above the key hints for a few seconds.
  private func confirm(_ confirmation: Confirmation) {
    withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .snappy) { self.confirmation = confirmation }
    let id = confirmation.id
    Task {
      try? await Task.sleep(for: .seconds(4))
      if self.confirmation?.id == id {
        withAnimation(.easeOut(duration: 0.3)) { self.confirmation = nil }
      }
    }
  }

  /// Leaves the panel; after Where I left off, opens the Anchors of the Loop just Focused.
  private func close() {
    let pending = anchorsToOpenAfterLeftOff
    anchorsToOpenAfterLeftOff = nil
    dismiss()
    if let pending { model.anchors(of: pending).forEach(AnchorOpener.open) }
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

  /// Asks Where I left off in a freshly built panel rather than by switching this view's mode: the
  /// switch animates, and the cursor went to the old field on its way out, so ↩ and esc did nothing.
  private func askWhereILeftOff(_ loop: Loop) {
    showLeftOff(loop, anchorsToOpenAfterLeftOff)
  }

  private func contextLine(_ context: CaptureContext) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        AppIcon(bundleID: context.anchor.source.bundleID, size: 14)
        Text(context.anchor.title).lineLimit(1)
      }
      .font(.callout)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(Capsule().fill(Color.primary.opacity(0.06)))
      .help("Where you are now. ⌘↩ captures with it as the Anchor; ⇥ copies its title into the field.")
      if context.missingAccessibility {
        HStack(spacing: 10) {
          Image(systemName: "hand.raised").font(.system(size: 15, weight: .medium)).foregroundStyle(Style.looseEnd)
          VStack(alignment: .leading, spacing: 1) {
            Text("unfocused can't see window titles yet").font(.callout.weight(.medium))
            Text("Allow it under Accessibility in System Settings to capture the exact window.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Button("Open Settings") { Permissions.requestAccessibility() }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Style.rowRadius).fill(Style.looseEnd.opacity(0.1)))
      }
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 10)
  }

  // MARK: Where I left off

  /// Where did you leave off? The Loop being left and the last note come first and largest; the
  /// question and field follow. With a last note, ↩ on an empty field keeps it.
  @ViewBuilder private func leftOffContent(_ loop: Loop) -> some View {
    let typed = !text.trimmingCharacters(in: .whitespaces).isEmpty
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Leaving").font(.callout.weight(.medium)).foregroundStyle(.secondary)
        Text(loop.title).font(.system(size: 26, weight: .semibold)).lineLimit(2)
      }

      if let note = loop.whereILeftOff {
        VStack(alignment: .leading, spacing: 6) {
          Label("Last time you left off at", systemImage: "bookmark")
            .font(.callout.weight(.medium))
            .foregroundStyle(.secondary)
          Text(note).font(.title3).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(typed ? 0.04 : 0.08)))
        .opacity(typed ? 0.6 : 1)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text(loop.whereILeftOff == nil ? "Where did you leave off?" : "Anything new?")
          .font(.headline)
        inputField(
          loop.whereILeftOff == nil
            ? "e.g. Halfway through section 2, next: permissions"
            : "Type a new note, or ↩ to keep the last one"
        )
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.06)))
        .onKeyPress(.return) {
          model.setWhereILeftOff(loop, to: text)
          close()
          return .handled
        }
      }
    }
    .padding(.horizontal, 32)
    .padding(.top, 28)

    Spacer(minLength: 0)
    hints([
      loop.whereILeftOff != nil && !typed ? "↩ Keep" : "↩ Save",
      "esc Skip",
    ])
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
      Button("Close Loop") {
        model.close(loop)
        dismiss()
      }
      .keyboardShortcut("c", modifiers: .command)
      Button("Let go") {
        model.letGo(loop)
        dismiss()
      }
      .keyboardShortcut("l", modifiers: .command)
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
    hints(["↩ Continue", "⌘C Close Loop", "⌘L Let go", "⌘U Unfocus", "esc Ask me later"])
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
        close()
        return .handled
      }
  }

  private func hints(_ items: [String]) -> some View {
    KeyHints(items: items)
  }

}

/// What the panel just did, shown briefly with an undo.
struct Confirmation: Identifiable {
  let id = UUID()
  let text: String
  let systemImage: String
  /// Closing a Loop gets the logo gradient; Let go and hints stay neutral.
  let celebrate: Bool
  let undo: (() -> Void)?
}

struct ConfirmationBar: View {
  let confirmation: Confirmation

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: confirmation.systemImage)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(confirmation.celebrate ? AnyShapeStyle(Style.logoLinearGradient) : AnyShapeStyle(.secondary))
      Text(confirmation.text).font(.callout.weight(.medium)).lineLimit(1)
      if confirmation.undo != nil {
        KeyHints.Keycap(key: "⌘Z")
        Text("Undo").font(.callout).foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(Capsule().fill(Color(nsColor: .windowBackgroundColor)))
    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12)))
    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
  }
}
