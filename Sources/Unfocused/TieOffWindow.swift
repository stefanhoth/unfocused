import AppKit
import SwiftUI
import UnfocusedCore

/// Opens the Tie-off in its own window, from the menu or the daily reminder.
@MainActor
final class TieOffController {
  private let model: AppModel
  private var window: FloatingPanel?

  init(model: AppModel) {
    self.model = model
  }

  func show() {
    model.refresh()
    let window = window ?? makeWindow()
    self.window = window
    // A fresh view each time, so each Tie-off starts from the current Loose Ends.
    window.contentView = NSHostingView(
      rootView: TieOffView(model: model, tieOff: model.startTieOff(), close: { [weak window] in window?.close() })
    )
    window.center()
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }

  /// A floating sheet of glass, like the panel: the SwiftUI view draws everything.
  private func makeWindow() -> FloatingPanel {
    let window = FloatingPanel(
      contentRect: NSRect(
        x: 0,
        y: 0,
        width: Style.tieOffSize.width + 2 * Style.glowMargin,
        height: Style.tieOffSize.height + 2 * Style.glowMargin
      ),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.title = "Tie-off"
    window.isOpaque = false
    window.backgroundColor = .clear
    // Own shadow and glow in the view, like the panel: the system shadow follows the rectangle.
    window.hasShadow = false
    window.isMovableByWindowBackground = true
    window.level = .floating
    window.isReleasedWhenClosed = false
    return window
  }
}

/// One Loose End at a time, every action on a single key.
struct TieOffView: View {
  let model: AppModel
  @State var tieOff: TieOff
  let close: () -> Void
  @State private var celebrated = false
  /// The last step, for ⌘Z: which Loop, and whether it was Closed or let go (and needs reopening).
  @State private var lastStep: (loop: Loop, reopen: Bool)?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var motion: CalmMotion { CalmMotion(reduceMotion: reduceMotion) }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let current = tieOff.current {
        progress
        card(current)
        Spacer(minLength: 0)
        actions(current)
      } else {
        finished
      }
    }
    .frame(width: Style.tieOffSize.width, height: Style.tieOffSize.height)
    .calmGlass(cornerRadius: Style.tieOffRadius)
    .overlay(GradientGlow(cornerRadius: Style.tieOffRadius))
    .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
    .padding(Style.glowMargin)
    .tint(Style.brand)
    .background {
      // ⌘Z takes back the last step; a hidden button carries the shortcut.
      Button("Undo") { undo() }.keyboardShortcut("z", modifiers: .command).hidden()
    }
  }

  // MARK: One Loose End

  private var progress: some View {
    VStack(spacing: 10) {
      HStack {
        Text("Tie-off").font(.caption.weight(.medium)).foregroundStyle(.secondary)
        Spacer()
        if lastStep != nil {
          KeyHints.Hint(item: KeyHint("⌘Z Undo", action: undo)).font(.caption).foregroundStyle(.secondary)
        }
        Text("\(tieOff.done + 1) of \(tieOff.total)").font(.caption).monospacedDigit().foregroundStyle(.secondary)
      }
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(.quaternary)
          Capsule()
            .fill(Style.looseEnd)
            .frame(width: geometry.size.width * Double(tieOff.done + 1) / Double(max(tieOff.total, 1)))
        }
      }
      .frame(height: 4)
    }
    .padding([.horizontal, .top], 28)
  }

  /// The same summary as the panel's detail, so a Loose End reads the same everywhere.
  private func card(_ aging: LoopAging) -> some View {
    LoopSummary(model: model, loop: aging.loop, prominent: true) { EmptyView() }
      .padding(.horizontal, 28)
      .padding(.vertical, 20)
      .id(aging.loop.id)
      .transition(.asymmetric(insertion: motion.slide(from: .trailing), removal: motion.slide(from: .leading)))
  }

  private func actions(_ aging: LoopAging) -> some View {
    let loop = aging.loop
    let anchors = model.anchors(of: loop)
    let focusLabel =
      aging.followUp.isEmpty ? "Focus" : "Follow up with \(aging.followUp.map(\.name).formatted(.list(type: .and)))"
    return VStack(alignment: .leading, spacing: 10) {
      HStack {
        Button {
          // Not opening Anchors here: those apps would take the keyboard from the Tie-off. O opens them.
          model.focus(loop, openAnchors: false)
          advance(loop, reopen: false)
        } label: {
          keyLabel(focusLabel, "F")
        }
        .keyboardShortcut("f", modifiers: [])
        .buttonStyle(.glassProminent)
        Button {
          model.close(loop)
          advance(loop, reopen: true)
        } label: {
          keyLabel("Close Loop", "C")
        }
        .keyboardShortcut("c", modifiers: [])
        .buttonStyle(.glass)
        Button {
          model.letGo(loop)
          advance(loop, reopen: true)
        } label: {
          keyLabel("Let go", "L")
        }
        .keyboardShortcut("l", modifiers: [])
        .buttonStyle(.glass)
      }
      HStack {
        Button {
          anchors.forEach(AnchorOpener.open)
        } label: {
          keyLabel("Open Anchors", "O")
        }
        .keyboardShortcut("o", modifiers: [])
        .buttonStyle(.glass)
        .disabled(anchors.isEmpty)
        Button {
          withAnimation(motion.snappy) { tieOff.notNow() }
          lastStep = (loop, false)
          celebrateIfDone()
        } label: {
          keyLabel("Not now", "N")
        }
        .keyboardShortcut("n", modifiers: [])
        .buttonStyle(.glass)
        Spacer()
        Button("Stop", action: close).keyboardShortcut(.cancelAction).buttonStyle(.borderless)
      }
    }
    .controlSize(.large)
    .padding(28)
  }

  private func keyLabel(_ title: String, _ key: String) -> some View {
    HStack(spacing: 8) {
      Text(title).lineLimit(1)
      KeyHints.Keycap(key: key)
    }
  }

  private func advance(_ loop: Loop, reopen: Bool) {
    withAnimation(motion.snappy) { tieOff.next() }
    lastStep = (loop, reopen)
    celebrateIfDone()
  }

  /// Takes back the last step: reopens a Closed or let-go Loop and shows it again.
  private func undo() {
    guard let lastStep else { return }
    if lastStep.reopen { model.reopen(lastStep.loop) }
    withAnimation(motion.snappy) { tieOff.back() }
    self.lastStep = nil
  }

  // MARK: Done

  private var finished: some View {
    VStack(spacing: 14) {
      Spacer()
      Image(systemName: tieOff.total == 0 ? "checkmark.circle" : "checkmark.seal.fill")
        .font(.system(size: 64))
        .foregroundStyle(Style.logoLinearGradient)
        .symbolEffect(.bounce, value: reduceMotion ? false : celebrated)
        .scaleEffect(celebrated || reduceMotion ? 1 : 0.6)
        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: celebrated)
      Text(tieOff.total == 0 ? "No Loose Ends" : "All tied off").font(.title2.weight(.semibold))
      Text(summary).foregroundStyle(.secondary).multilineTextAlignment(.center)
      Spacer()
      Button("Finish", action: close).keyboardShortcut(.defaultAction).buttonStyle(.glassProminent)
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .onAppear { celebrated = true }
  }

  private var summary: String {
    if tieOff.total == 0 { return "Everything you've started has been touched recently." }
    let resolved = tieOff.total - tieOff.setAside.count
    let aside = tieOff.setAside.count
    return aside == 0
      ? "You went through \(resolved) Loose End\(resolved == 1 ? "" : "s")."
      : "You went through \(resolved) and set \(aside) aside for next time."
  }

  private func celebrateIfDone() {
    guard tieOff.isFinished, tieOff.total > 0 else { return }
    NSSound(named: "Glass")?.play()
  }
}
