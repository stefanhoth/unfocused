import SwiftUI

/// Direction A: calm, native Liquid Glass. Spacious, quiet, feels like part of macOS.
enum CalmGlass {
  struct Panel: View {
    var body: some View {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 10) {
          Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
          Text(Sample.typed).font(.system(size: 22, weight: .regular))
          Spacer()
        }
        .padding(18)

        HStack(spacing: 6) {
          Image(systemName: "globe").font(.caption)
          Text(Sample.context).font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .padding(.bottom, 12)

        Divider().opacity(0.4)

        VStack(alignment: .leading, spacing: 2) {
          Text("Add to an existing Loop instead?")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 10)
          ForEach(Array(Sample.loops.prefix(3).enumerated()), id: \.element.id) { index, loop in
            row(loop, selected: index == 0, key: "⌘\(index + 1)")
          }
        }
        .padding(8)

        Label("3 Loose Ends are older than this idea", systemImage: "hourglass")
          .font(.caption)
          .foregroundStyle(.orange)
          .padding(.horizontal, 20)

        Spacer(minLength: 0)
        HStack(spacing: 18) {
          ForEach(["⌘↩ Capture", "↩ Focus", "⌥↩ Add here", "esc"], id: \.self) { Text($0) }
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
        .padding(16)
      }
      .frame(width: 640, height: 400)
      .glass(in: .rect(cornerRadius: 24))
    }

    private func row(_ loop: SampleLoop, selected: Bool, key: String) -> some View {
      HStack(spacing: 10) {
        AgingRing(progress: loop.aging, color: .orange)
        VStack(alignment: .leading, spacing: 2) {
          Text(loop.title)
          if let followUp = loop.followUp {
            Text("Follow up with \(followUp)?").font(.caption).foregroundStyle(.orange)
          }
        }
        Spacer()
        Text(key).font(.caption).foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(selected ? Color.accentColor.opacity(0.15) : .clear, in: .rect(cornerRadius: 10))
    }
  }

  struct TieOff: View {
    var body: some View {
      let loop = Sample.tieOff
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text("Tie-off").font(.caption.weight(.medium)).foregroundStyle(.secondary)
          Spacer()
          Text("1 of 4").font(.caption).foregroundStyle(.secondary)
        }
        GeometryReader { geometry in
          ZStack(alignment: .leading) {
            Capsule().fill(.black.opacity(0.08))
            Capsule().fill(.orange).frame(width: geometry.size.width * 0.25)
          }
        }
        .frame(height: 4)
        Text(loop.title).font(.system(size: 26, weight: .semibold))
        Text("Follow up with Ada?").foregroundStyle(.orange)
        if let note = loop.note {
          Label(note, systemImage: "bookmark").foregroundStyle(.secondary)
        }
        Label("Mail · Re: Renewal terms", systemImage: "envelope").font(.callout).foregroundStyle(.secondary)
        Spacer()
        GlassEffectContainer {
          HStack(spacing: 10) {
            ForEach(["Follow up  F", "Close  C", "Drop  D", "Open  O", "Not now  N"], id: \.self) { title in
              Text(title)
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glass(in: .capsule, interactive: true)
            }
          }
        }
      }
      .padding(28)
      .frame(width: 560, height: 420)
      .glass(in: .rect(cornerRadius: 28))
    }
  }
}

struct AgingRing: View {
  let progress: Double
  let color: Color
  var size: CGFloat = 12

  var body: some View {
    ZStack {
      Circle().stroke(.quaternary, lineWidth: 2)
      Circle()
        .trim(from: 0, to: progress)
        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .rotationEffect(.degrees(-90))
      if progress >= 1 { Circle().fill(color).padding(3) }
    }
    .frame(width: size, height: size)
  }
}

private struct IsStillKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  /// Rendering a still image: ImageRenderer can't draw Liquid Glass, so it's approximated.
  var isStill: Bool {
    get { self[IsStillKey.self] }
    set { self[IsStillKey.self] = newValue }
  }
}

private struct Glass<S: Shape>: ViewModifier {
  let shape: S
  let interactive: Bool
  @Environment(\.isStill) private var isStill

  func body(content: Content) -> some View {
    if isStill {
      content
        .background(shape.fill(.white.opacity(interactive ? 0.35 : 0.55)))
        .overlay(shape.stroke(.white.opacity(0.7), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    } else {
      content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
    }
  }
}

extension View {
  func glass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
    modifier(Glass(shape: shape, interactive: interactive))
  }
}
