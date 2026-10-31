import SwiftUI

/// The Calm Glass look (ticket #17): Liquid Glass on floating chrome only, system vibrancy for
/// hierarchy, key hints always visible. Windows with lots of text stay solid.
enum Style {
  static let panelRadius: CGFloat = 24
  static let tieOffRadius: CGFloat = 28
  static let bannerRadius: CGFloat = 18
  static let rowRadius: CGFloat = 10
  /// Loose Ends and aging: the one warm accent in an otherwise calm palette.
  static let looseEnd = Color.orange
  /// Focus: always green, whatever the system accent color is.
  static let focus = Color.green

  /// A row's background: a clear accent tint when selected, nothing otherwise (no glass on glass).
  static func rowBackground(selected: Bool) -> some View {
    RoundedRectangle(cornerRadius: rowRadius).fill(selected ? Color.accentColor.opacity(0.18) : .clear)
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

/// The footer of key hints, shown on every floating surface.
struct KeyHints: View {
  let items: [String]

  var body: some View {
    HStack(spacing: 16) {
      ForEach(items, id: \.self) { Text($0) }
      Spacer()
    }
    .font(.caption)
    .foregroundStyle(.tertiary)
    .padding(.horizontal, 18)
    .padding(.vertical, 12)
  }
}
