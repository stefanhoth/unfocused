import AppKit
import SwiftUI
import UnfocusedCore

/// The Calm Glass look (ticket #17): Liquid Glass on floating chrome only, system vibrancy for
/// hierarchy, key hints always visible. Windows with lots of text stay solid.
enum Style {
  static let panelRadius: CGFloat = 24
  /// The panel: a list of Loops on the left, the selected Loop's details on the right.
  static let panelSize = CGSize(width: 880, height: 440)
  static let panelListWidth: CGFloat = 380
  /// Transparent room around floating surfaces for their own shadow and glow.
  static let glowMargin: CGFloat = 36
  /// The app's own tint (the icon's blue), so controls don't take on a red system accent and read
  /// as warnings.
  static let brand = Color(red: 0.42, green: 0.64, blue: 0.96)
  static let logoLinearGradient = LinearGradient(
    colors: logoGradient,
    startPoint: .leading,
    endPoint: .trailing
  )
  /// How much of the window background color sits under the glass: more is easier to read.
  static let glassBacking = 0.6
  /// The app icon's gradient: sky blue to peach.
  static let logoGradient: [Color] = [
    Color(red: 0.42, green: 0.64, blue: 0.96),
    Color(red: 0.55, green: 0.80, blue: 0.97),
    Color(red: 0.98, green: 0.76, blue: 0.58),
    Color(red: 0.96, green: 0.58, blue: 0.45),
  ]
  static let tieOffRadius: CGFloat = 28
  static let tieOffSize = CGSize(width: 600, height: 460)
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
    // Within a minute (including a moment "in the future" from clock jitter) it's just now.
    if abs(now.timeIntervalSince(date)) < 60 { return "just now" }
    return relativeFormatter.localizedString(for: date, relativeTo: now)
  }
}

extension View {
  /// A floating surface of Liquid Glass.
  /// A floating surface of Liquid Glass with a backing layer, so text behind it doesn't compete
  /// with the text on it (the plain glass let busy pages show through too much).
  func calmGlass(cornerRadius: CGFloat) -> some View {
    background(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(Color(nsColor: .windowBackgroundColor).opacity(Style.glassBacking))
    )
    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
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

/// One key hint: "<key> <what it does>", e.g. "⌘↩ Capture new". With an action, the hint is also
/// a button, so everything the keys do can be done with the mouse too (DESIGN.md).
struct KeyHint: ExpressibleByStringLiteral {
  let text: String
  var action: (() -> Void)?

  init(_ text: String, action: (() -> Void)? = nil) {
    self.text = text
    self.action = action
  }

  init(stringLiteral text: String) {
    self.init(text)
  }

  var key: String { String(text.split(separator: " ", maxSplits: 1).first ?? "") }
  var label: String? { text.split(separator: " ", maxSplits: 1).dropFirst().first.map(String.init) }
}

/// The footer of key hints, shown on every floating surface: each key as a small keycap.
/// Hints with an action can be clicked.
struct KeyHints: View {
  let items: [KeyHint]
  /// `false` for a row of actions inside content (no padding, no divider), e.g. under a Loop.
  var footer = true

  var body: some View {
    if footer {
      row
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Divider().opacity(0.5) }
    } else {
      row
    }
  }

  private var row: some View {
    // Each hint carries 6 pt of padding for its hover fill, so the gaps between labels stay at 14 pt.
    HStack(spacing: 2) {
      ForEach(items, id: \.text) { item in
        Hint(item: item)
      }
      Spacer()
    }
    .font(.system(size: 12))
    .foregroundStyle(.secondary)
  }
}

extension KeyHints {
  /// A keycap and its label; a button when the hint has an action.
  struct Hint: View {
    let item: KeyHint

    var body: some View {
      let content = HStack(spacing: 5) {
        Keycap(key: item.key)
        if let label = item.label { Text(label) }
      }
      if let action = item.action {
        Button(action: action) { content }
          .buttonStyle(HintButtonStyle())
          .help(item.label ?? item.key)
      } else {
        content.padding(.horizontal, 6).padding(.vertical, 3)
      }
    }
  }

  /// A key hint you can click: no chrome until the pointer is over it, then a quiet fill.
  struct HintButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
      HoverHighlight(pressed: configuration.isPressed) { configuration.label }
    }
  }
}

/// A quiet fill under the pointer, for clickable rows and hints that otherwise look like text.
struct HoverHighlight<Content: View>: View {
  var pressed = false
  var cornerRadius: CGFloat = 6
  @ViewBuilder let content: () -> Content
  @State private var hovering = false

  var body: some View {
    content()
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.primary.opacity(pressed ? 0.12 : hovering ? 0.07 : 0))
      )
      .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
      .onHover { hovering = $0 }
  }
}

extension KeyHints {
  /// One key, drawn as a small keycap.
  struct Keycap: View {
    let key: String

    var body: some View {
      Text(key)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.1)))
    }
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

/// A thin, crisp edge in the logo's gradient with a tight halo, drawn over a floating surface so
/// it stands out from whatever is behind. It drifts slowly; with Reduce Motion it stays still.
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
      // A tight halo just outside the edge, then a crisp line on the edge itself.
      shape.stroke(gradient, lineWidth: 3).blur(radius: 5).opacity(0.9)
      shape.strokeBorder(gradient, lineWidth: 1.5)
    }
    .allowsHitTesting(false)
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) { angle = 360 }
    }
  }
}

/// A number with its label, as at the top of the Recap and Activity.
struct FigureCard: View {
  let value: String
  let label: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value).font(.title.weight(.semibold)).monospacedDigit()
      Text(label).font(.caption).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
  }
}

extension Style {
  /// "45s", "8m", "1h 5m": short durations for lists.
  static func shortDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded())
    if total < 60 { return "\(total)s" }
    let minutes = total / 60
    if minutes < 60 { return "\(minutes)m" }
    return "\(minutes / 60)h \(minutes % 60)m"
  }
}

extension Source {
  var displayName: String {
    switch self {
    case .safari: "Safari"
    case .chrome: "Chrome"
    case .firefox: "Firefox"
    case .app(let bundleID):
      NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        .map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
        ?? bundleID
    }
  }
}
