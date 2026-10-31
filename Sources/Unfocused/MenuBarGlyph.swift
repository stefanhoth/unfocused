import AppKit

/// The menu bar mark: an open loop, a ring with a gap at the top right. While a Loop is Focused,
/// a dot sits in the middle. Drawn as a template image so macOS tints it for light and dark bars.
enum MenuBarGlyph {
  static func image(focused: Bool) -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size, flipped: false) { rect in
      let center = NSPoint(x: rect.midX, y: rect.midY)
      let ring = NSBezierPath()
      // Angles run counter-clockwise from the right; the gap sits between 20° and 70° (top right).
      ring.appendArc(withCenter: center, radius: 6.5, startAngle: 70, endAngle: 380, clockwise: false)
      ring.lineWidth = 2
      ring.lineCapStyle = .round
      NSColor.black.setStroke()
      ring.stroke()
      if focused {
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5)).fill()
      }
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = focused ? "unfocused, a Loop is Focused" : "unfocused"
    return image
  }
}
