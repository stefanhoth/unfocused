import AppKit
import SwiftUI

/// The Calm Glass look (ticket #17): Liquid Glass on floating chrome only, system vibrancy for
/// hierarchy, key hints always visible. Windows with lots of text stay solid.
enum Style {
  static let panelRadius: CGFloat = 24
  /// The panel: a list of Loops on the left, the selected Loop's details on the right.
  static let panelSize = CGSize(width: 880, height: 440)
  static let panelListWidth: CGFloat = 380
  /// Transparent room around floating surfaces for their own shadow and glow.
  static let glowMargin: CGFloat = 36
  /// The app icon's gradient: sky blue to peach.
  static let logoGradient: [Color] = [
    Color(red: 0.42, green: 0.64, blue: 0.96),
    Color(red: 0.55, green: 0.80, blue: 0.97),
    Color(red: 0.98, green: 0.76, blue: 0.58),
    Color(red: 0.96, green: 0.58, blue: 0.45),
  ]
  static let tieOffRadius: CGFloat = 28
  static let bannerRadius: CGFloat = 18
  static let rowRadius: CGFloat = 10
  /// Loose Ends and aging: the one warm accent in an otherwise calm palette.
  static let looseEnd = Color.orange
  /// Focus: always green, whatever the system accent color is.
  static let focus = Color.green

  /// A row's background: a clear accent tint when selected, nothing otherwise (no glass on glass).
  /// A quiet, neutral highlight that works with any accent color and doesn't read as a warning.
  static func rowBackground(selected: Bool) -> some View {
    RoundedRectangle(cornerRadius: rowRadius)
      .fill(Color.primary.opacity(selected ? 0.09 : 0))
      .overlay(RoundedRectangle(cornerRadius: rowRadius).strokeBorder(Color.primary.opacity(selected ? 0.08 : 0)))
  }

  @MainActor private static let relativeFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    // The interface is English; mixing in the system language ("vor 10 Sekunden") reads oddly.
    formatter.locale = Locale(identifier: "en_US")
    formatter.unitsStyle = .full
    return formatter
  }()

  /// "10 seconds ago", "2 days ago", in the interface language.
  @MainActor static func relative(_ date: Date, to now: Date = Date()) -> String {
    relativeFormatter.localizedString(for: date, relativeTo: now)
  }
}

extension View {
  /// A floating surface of Liquid Glass.
  func calmGlass(cornerRadius: CGFloat) -> some View {
    glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
  }
}

/// Animation that turns into a simple fade when the user asked for less motion.
struct CalmMotion {
  let reduceMotion: Bool

  var snappy: Animation { reduceMotion ? .easeInOut(duration: 0.15) : .snappy }

  func slide(from edge: Edge) -> AnyTransition {
    reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
  }
}

/// The footer of key hints, shown on every floating surface: each key as a small keycap.
/// Items read "<key> <what it does>", e.g. "⌘↩ Capture new".
struct KeyHints: View {
  let items: [String]

  var body: some View {
    HStack(spacing: 14) {
      ForEach(items, id: \.self) { item in
        let parts = item.split(separator: " ", maxSplits: 1).map(String.init)
        HStack(spacing: 5) {
          Text(parts[0])
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.1)))
          if parts.count > 1 { Text(parts[1]) }
        }
      }
      Spacer()
    }
    .font(.system(size: 12))
    .foregroundStyle(.secondary)
    .padding(.horizontal, 18)
    .padding(.vertical, 12)
    .overlay(alignment: .top) { Divider().opacity(0.5) }
  }
}

/// A small app icon, e.g. next to an Anchor; a generic symbol if the app isn't installed.
struct AppIcon: View {
  let bundleID: String
  var size: CGFloat = 16

  var body: some View {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
      Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
        .resizable()
        .frame(width: size, height: size)
    } else {
      Image(systemName: "app.dashed").frame(width: size, height: size)
    }
  }
}

/// A soft glow in the logo's gradient around a floating surface, with a thin gradient edge. It
/// drifts slowly; with Reduce Motion it stays still.
struct GradientGlow: View {
  let cornerRadius: CGFloat
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var angle = 0.0

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    let gradient = AngularGradient(
      colors: Style.logoGradient + [Style.logoGradient[0]],
      center: .center,
      angle: .degrees(angle)
    )
    ZStack {
      shape.stroke(gradient, lineWidth: 14).blur(radius: 22).opacity(0.55)
      shape.strokeBorder(gradient, lineWidth: 1.5).opacity(0.85)
    }
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) { angle = 360 }
    }
  }
}
