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
      contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.title = "Tie-off"
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
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
    .frame(width: 560, height: 420)
    .calmGlass(cornerRadius: Style.tieOffRadius)
  }

  // MARK: One Loose End

  private var progress: some View {
    VStack(spacing: 10) {
      HStack {
        Text("Tie-off").font(.caption.weight(.medium)).foregroundStyle(.secondary)
        Spacer()
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

  private func card(_ aging: LoopAging) -> some View {
    let loop = aging.loop
    let people = model.involvements(of: loop)
    let anchors = model.anchors(of: loop)
    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        AgingMark(aging: aging)
        Text(loop.title).font(.system(size: 26, weight: .semibold)).lineLimit(3)
      }
      LooseEndNote(aging: aging)
      if let note = loop.whereILeftOff {
        Label(note, systemImage: "bookmark").foregroundStyle(.secondary)
      }
      if !people.isEmpty {
        HStack(spacing: 8) {
          ForEach(people, id: \.person.id) { involvement in
            Label(
              "\(involvement.person.name) · \(involvement.direction.label)",
              systemImage: involvement.direction == .owed ? "arrow.left" : "arrow.right"
            )
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
            .help(involvement.direction.help)
          }
        }
      }
      if !anchors.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(Array(anchors.prefix(3).enumerated()), id: \.offset) { _, anchor in
            Label(anchor.title, systemImage: "link").font(.callout).lineLimit(1).foregroundStyle(.secondary)
          }
        }
      }
    }
    .padding(.horizontal, 28)
    .padding(.vertical, 20)
    .id(loop.id)
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
          model.focus(loop)
          advance()
        } label: {
          keyLabel(focusLabel, "F")
        }
        .keyboardShortcut("f", modifiers: [])
        .buttonStyle(.glassProminent)
        Button {
          model.close(loop)
          advance()
        } label: {
          keyLabel("Close Loop", "C")
        }
        .keyboardShortcut("c", modifiers: [])
        .buttonStyle(.glass)
        Button {
          model.letGo(loop)
          advance()
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
    HStack(spacing: 6) {
      Text(title).lineLimit(1)
      Text(key).font(.caption.monospaced()).foregroundStyle(.secondary)
    }
  }

  private func advance() {
    withAnimation(motion.snappy) { tieOff.next() }
    celebrateIfDone()
  }

  // MARK: Done

  private var finished: some View {
    VStack(spacing: 14) {
      Spacer()
      Image(systemName: tieOff.total == 0 ? "checkmark.circle" : "checkmark.seal.fill")
        .font(.system(size: 64))
        .foregroundStyle(.green)
        .symbolEffect(.bounce, value: reduceMotion ? false : celebrated)
        .scaleEffect(celebrated || reduceMotion ? 1 : 0.6)
        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: celebrated)
      Text(tieOff.total == 0 ? "No Loose Ends" : "All tied off").font(.title2.weight(.semibold))
      Text(summary).foregroundStyle(.secondary).multilineTextAlignment(.center)
      Spacer()
      Button("Done", action: close).keyboardShortcut(.defaultAction).buttonStyle(.glassProminent)
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
