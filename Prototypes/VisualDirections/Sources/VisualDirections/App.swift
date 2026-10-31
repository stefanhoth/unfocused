import AppKit
import SwiftUI

enum Direction: String, CaseIterable, Identifiable {
  case calmGlass = "A · Calm Glass"
  case playful = "B · Playful"
  case dense = "C · Dense, keyboard-first"

  var id: String { rawValue }

  @ViewBuilder var panel: some View {
    switch self {
    case .calmGlass: CalmGlass.Panel()
    case .playful: Playful.Panel()
    case .dense: Dense.Panel()
    }
  }

  @ViewBuilder var tieOff: some View {
    switch self {
    case .calmGlass: CalmGlass.TieOff()
    case .playful: Playful.TieOff()
    case .dense: Dense.TieOff()
    }
  }
}

/// A desktop-like backdrop so glass and shadows have something to sit on.
struct Backdrop: View {
  var body: some View {
    LinearGradient(
      colors: [Color(red: 0.36, green: 0.42, blue: 0.62), Color(red: 0.78, green: 0.56, blue: 0.52)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}

struct Board: View {
  let direction: Direction

  var body: some View {
    HStack(alignment: .top, spacing: 32) {
      direction.panel
      direction.tieOff
    }
    .padding(40)
    .background(Backdrop())
  }
}

struct Gallery: View {
  @State private var direction = Direction.calmGlass

  var body: some View {
    VStack(spacing: 0) {
      Picker("Direction", selection: $direction) {
        ForEach(Direction.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)
      .padding(12)
      Board(direction: direction)
    }
  }
}

@main
struct VisualDirections {
  @MainActor
  static func main() {
    let arguments = CommandLine.arguments
    if let index = arguments.firstIndex(of: "--render"), arguments.indices.contains(index + 1) {
      render(to: URL(fileURLWithPath: arguments[index + 1]))
      return
    }
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1340, height: 560),
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "unfocused · visual directions (#17)"
    window.contentView = NSHostingView(rootView: Gallery())
    window.center()
    window.makeKeyAndOrderFront(nil)
    app.activate()
    app.run()
  }

  @MainActor
  static func render(to directory: URL) {
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for (index, direction) in Direction.allCases.enumerated() {
      let renderer = ImageRenderer(content: Board(direction: direction).environment(\.isStill, true))
      renderer.scale = 2
      guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
        let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
      else { continue }
      let name = ["a-calm-glass", "b-playful", "c-dense"][index]
      try? png.write(to: directory.appendingPathComponent("\(name).png"))
      print("wrote \(name).png")
    }
  }
}
