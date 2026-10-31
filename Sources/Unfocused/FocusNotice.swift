import AppKit
import SwiftUI
import UnfocusedCore

/// A short glass notice at the bottom of the screen when Focus changes: it fades in, stays a
/// moment and fades out. It never takes keyboard focus or clicks.
@MainActor
final class FocusNotice {
  private var panel: NSPanel?
  private var hideTask: Task<Void, Never>?

  func show(focused: Loop?, left: Loop?) {
    let content: FocusNoticeView
    if let focused {
      content = FocusNoticeView(caption: "Focused", title: focused.title, note: focused.whereILeftOff, isFocus: true)
    } else if let left {
      content = FocusNoticeView(caption: "Unfocused", title: left.title, note: nil, isFocus: false)
    } else {
      return
    }

    let panel = panel ?? makePanel()
    self.panel = panel
    let hosting = NSHostingView(rootView: content)
    panel.contentView = hosting
    let size = hosting.fittingSize
    if let screen = NSScreen.main?.visibleFrame {
      panel.setFrame(
        NSRect(
          x: screen.midX - size.width / 2,
          // Bottom center, above the Dock, where macOS shows its own notices; clear of window title bars.
          y: screen.minY + 72,
          width: size.width,
          height: size.height
        ),
        display: true
      )
    }

    // VoiceOver users hear it, since the notice can't be reached with the keyboard.
    NSAccessibility.post(
      element: NSApp as Any,
      notification: .announcementRequested,
      userInfo: [
        .announcement: "\(content.caption): \(content.title)", .priority: NSAccessibilityPriorityLevel.medium.rawValue,
      ]
    )

    hideTask?.cancel()
    panel.alphaValue = 0
    panel.orderFrontRegardless()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.2
      panel.animator().alphaValue = 1
    }
    // Long enough to read the title, plus a moment for Where I left off.
    let hold: Duration = content.note == nil ? .seconds(1.6) : .seconds(2.6)
    hideTask = Task { [weak panel] in
      try? await Task.sleep(for: hold)
      guard !Task.isCancelled, let panel else { return }
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.5
        panel.animator().alphaValue = 0
      } completionHandler: {
        MainActor.assumeIsolated {
          if panel.alphaValue == 0 { panel.orderOut(nil) }
        }
      }
    }
  }

  private func makePanel() -> NSPanel {
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 360, height: 64),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.level = .statusBar
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    return panel
  }
}

private struct FocusNoticeView: View {
  let caption: String
  let title: String
  let note: String?
  let isFocus: Bool

  var body: some View {
    HStack(spacing: 12) {
      Image(nsImage: MenuBarGlyph.image(focused: isFocus))
        .renderingMode(.template)
        .foregroundStyle(isFocus ? Color.accentColor : .secondary)
        .scaleEffect(1.3)
      VStack(alignment: .leading, spacing: 2) {
        Text(caption).font(.caption.weight(.medium)).foregroundStyle(.secondary)
        Text(title).font(.headline).lineLimit(1)
        if let note {
          Text("Where I left off: \(note)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 12)
    .frame(minWidth: 240, maxWidth: 420, alignment: .leading)
    .calmGlass(cornerRadius: Style.bannerRadius)
    .accessibilityElement(children: .combine)
  }
}
