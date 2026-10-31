import AppKit
import SwiftUI
import UnfocusedCore

/// The small "Switch Focus?" banner shown when the user seems to be working on another Loop.
/// It never takes keyboard focus away from what the user is doing.
@MainActor
final class SwitchBannerController {
  private let model: AppModel
  private let panelController: PanelController
  private var panel: NSPanel?
  private var shownLoop: Loop?

  init(model: AppModel, panelController: PanelController) {
    self.model = model
    self.panelController = panelController
  }

  /// Shows the banner for `loop`, or hides it when there's nothing to suggest.
  func update(_ loop: Loop?) {
    guard let loop else {
      hide()
      return
    }
    guard loop.id != shownLoop?.id else { return }
    shownLoop = loop
    show(loop)
  }

  private func show(_ loop: Loop) {
    let panel = panel ?? makePanel()
    self.panel = panel
    panel.contentView = NSHostingView(
      rootView: SwitchBanner(
        loop: loop,
        onSwitch: { [weak self] in self?.switchFocus(to: loop) },
        onNotNow: { [weak self] in self?.notNow() }
      )
    )
    let size = panel.contentView?.fittingSize ?? NSSize(width: 360, height: 72)
    if let screen = NSScreen.main?.visibleFrame {
      panel.setFrame(
        NSRect(
          x: screen.maxX - size.width - 16,
          y: screen.maxY - size.height - 16,
          width: size.width,
          height: size.height
        ),
        display: true
      )
    }
    panel.orderFrontRegardless()
  }

  private func hide() {
    shownLoop = nil
    panel?.orderOut(nil)
  }

  private func switchFocus(to loop: Loop) {
    hide()
    if let left = model.focus(loop, openAnchors: false) { panelController.askWhereILeftOff(left) }
  }

  private func notNow() {
    hide()
    model.notNowSilentSwitch()
  }

  private func makePanel() -> NSPanel {
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 360, height: 72),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    return panel
  }
}

private struct SwitchBanner: View {
  let loop: Loop
  let onSwitch: () -> Void
  let onNotNow: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Looks like you're on").font(.caption).foregroundStyle(.secondary)
        Text(loop.title).font(.headline).lineLimit(1)
      }
      Spacer(minLength: 8)
      Button("Not now", action: onNotNow)
      Button("Switch Focus", action: onSwitch).buttonStyle(.borderedProminent)
    }
    .padding(14)
    .frame(width: 380)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
  }
}
