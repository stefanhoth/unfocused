import SwiftUI

/// Direction C: dense and keyboard-first. Dark, compact rows, monospaced detail, keys everywhere.
enum Dense {
  static let background = Color(red: 0.09, green: 0.09, blue: 0.11)
  static let row = Color(red: 0.14, green: 0.14, blue: 0.17)
  static let accent = Color(red: 0.55, green: 0.80, blue: 1.0)
  static let amber = Color(red: 1.0, green: 0.70, blue: 0.30)

  struct Panel: View {
    var body: some View {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 8) {
          Text("›").font(.system(size: 18, design: .monospaced)).foregroundStyle(accent)
          Text(Sample.typed).font(.system(size: 17, weight: .medium))
          Rectangle().fill(accent).frame(width: 2, height: 20)
          Spacer()
          Text("notion.so").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        Rectangle().fill(.white.opacity(0.08)).frame(height: 1)

        sectionHeader("RELATED", trailing: "⌘1–3 add instead")
        ForEach(Array(Sample.loops.prefix(3).enumerated()), id: \.element.id) { index, loop in
          line(loop, key: "⌘\(index + 1)", selected: index == 0)
        }
        sectionHeader("LOOSE ENDS", trailing: "3 older than this")
        ForEach(Array(Sample.loops.suffix(2).enumerated()), id: \.element.id) { _, loop in
          line(loop, key: "", selected: false)
        }
        Spacer(minLength: 0)
        Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
        HStack(spacing: 14) {
          ForEach(["⌘↩ capture", "↩ focus", "⌥↩ anchor", "⌘K close", "⌘D drop", "@ person", "⇥ owed/waiting"], id: \.self) {
            Text($0)
          }
        }
        .font(.system(size: 10.5, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(10)
      }
      .foregroundStyle(.white)
      .frame(width: 640, height: 400)
      .background(Dense.background, in: .rect(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1)))
      .environment(\.colorScheme, .dark)
    }

    private func sectionHeader(_ title: String, trailing: String) -> some View {
      HStack {
        Text(title).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
        Spacer()
        Text(trailing).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 14)
      .padding(.top, 10)
      .padding(.bottom, 4)
    }

    private func line(_ loop: SampleLoop, key: String, selected: Bool) -> some View {
      HStack(spacing: 8) {
        Text(String(repeating: "▮", count: Int((loop.aging * 3).rounded())).padding(toLength: 3, withPad: "▯", startingAt: 0))
          .font(.system(size: 9, design: .monospaced))
          .foregroundStyle(loop.aging >= 1 ? amber : .secondary)
        Text(loop.title).font(.system(size: 13)).lineLimit(1)
        if let followUp = loop.followUp {
          Text("→ \(followUp)").font(.system(size: 11, design: .monospaced)).foregroundStyle(amber)
        }
        Spacer()
        Text(loop.source).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.tertiary)
        Text(key).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.secondary).frame(width: 24)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 5)
      .background(selected ? accent.opacity(0.18) : .clear)
    }
  }

  struct TieOff: View {
    static let keys: [(String, String)] = [
      ("F", "follow up"), ("C", "close"), ("D", "drop"), ("O", "open"), ("N", "not now"), ("esc", "stop"),
    ]

    var body: some View {
      let loop = Sample.tieOff
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text("TIE-OFF").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
          Spacer()
          Text("[1/4] ▮▯▯▯").font(.system(size: 11, design: .monospaced)).foregroundStyle(accent)
        }
        Text(loop.title).font(.system(size: 20, weight: .semibold))
        grid([
          ("state", "loose end · 4 active days"),
          ("waiting", "Ada → follow up?"),
          ("left off", loop.note ?? "–"),
          ("anchor", "mail://Re: Renewal terms"),
          ("captured", "Oct 21 · from Mail"),
        ])
        Spacer()
        HStack(spacing: 6) {
          ForEach(Self.keys, id: \.0) { key, label in
            HStack(spacing: 4) {
              Text(key)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(row, in: .rect(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.15)))
              Text(label).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
          }
        }
      }
      .foregroundStyle(.white)
      .padding(18)
      .frame(width: 560, height: 420)
      .background(Dense.background, in: .rect(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1)))
      .environment(\.colorScheme, .dark)
    }

    private func grid(_ rows: [(String, String)]) -> some View {
      VStack(alignment: .leading, spacing: 5) {
        ForEach(rows, id: \.0) { key, value in
          HStack(alignment: .firstTextBaseline) {
            Text(key).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
            Text(value).font(.system(size: 12, design: .monospaced))
          }
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(row, in: .rect(cornerRadius: 6))
    }
  }
}
