import SwiftUI

/// Direction B: playful. Warm colors, rounded type, springy motion and sound.
enum Playful {
  static let ink = Color(red: 0.13, green: 0.11, blue: 0.24)
  static let paper = Color(red: 1.0, green: 0.97, blue: 0.92)
  static let coral = Color(red: 1.0, green: 0.45, blue: 0.38)
  static let teal = Color(red: 0.16, green: 0.72, blue: 0.67)
  static let sun = Color(red: 1.0, green: 0.78, blue: 0.27)

  struct Panel: View {
    var body: some View {
      VStack(alignment: .leading, spacing: 14) {
        Text(Sample.typed)
          .font(.system(size: 24, weight: .bold, design: .rounded))
          .foregroundStyle(ink)
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.white, in: .rect(cornerRadius: 18))
          .overlay(RoundedRectangle(cornerRadius: 18).stroke(ink, lineWidth: 2))

        HStack(spacing: 8) {
          chip("📄 Notion · Q3 Hiring plan", teal)
          chip("Ada · Waiting", sun)
        }

        Text("Already on your plate?")
          .font(.system(.headline, design: .rounded))
          .foregroundStyle(ink)
        ForEach(Array(Sample.loops.prefix(3).enumerated()), id: \.element.id) { index, loop in
          HStack(spacing: 12) {
            Blob(progress: loop.aging)
            Text(loop.title).font(.system(.body, design: .rounded).weight(.medium)).foregroundStyle(ink)
            Spacer()
            Text("⌘\(index + 1)")
              .font(.system(.caption, design: .rounded).weight(.bold))
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(ink.opacity(0.08), in: .capsule)
          }
          .padding(10)
          .background(index == 0 ? sun.opacity(0.35) : .white.opacity(0.6), in: .rect(cornerRadius: 14))
        }
        Text("🧶 3 Loose Ends are older than this idea")
          .font(.system(.callout, design: .rounded))
          .foregroundStyle(coral)
        Spacer(minLength: 0)
      }
      .padding(20)
      .frame(width: 640, height: 400)
      .background(paper, in: .rect(cornerRadius: 26))
      .overlay(RoundedRectangle(cornerRadius: 26).stroke(ink, lineWidth: 3))
    }

    private func chip(_ text: String, _ color: Color) -> some View {
      Text(text)
        .font(.system(.caption, design: .rounded).weight(.semibold))
        .foregroundStyle(ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.5), in: .capsule)
    }
  }

  struct TieOff: View {
    var body: some View {
      let loop = Sample.tieOff
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          ForEach(0..<4) { index in
            Capsule().fill(index == 0 ? coral : ink.opacity(0.12)).frame(height: 8)
          }
        }
        Text("Let's tie some ends 🎀")
          .font(.system(.title3, design: .rounded).weight(.heavy))
          .foregroundStyle(coral)
        VStack(alignment: .leading, spacing: 10) {
          Text(loop.title).font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundStyle(ink)
          Text("Ada's been waiting 4 active days 👀").font(.system(.body, design: .rounded)).foregroundStyle(ink)
          if let note = loop.note {
            Text("🔖 \(note)").font(.system(.callout, design: .rounded)).foregroundStyle(ink.opacity(0.7))
          }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(ink, lineWidth: 2))
        .rotationEffect(.degrees(-1.2))
        Spacer()
        HStack(spacing: 10) {
          bigKey("F", "Follow up", teal)
          bigKey("C", "Close", sun)
          bigKey("D", "Drop", coral)
          bigKey("N", "Not now", ink.opacity(0.15))
        }
      }
      .padding(24)
      .frame(width: 560, height: 420)
      .background(paper, in: .rect(cornerRadius: 28))
      .overlay(RoundedRectangle(cornerRadius: 28).stroke(ink, lineWidth: 3))
    }

    private func bigKey(_ key: String, _ label: String, _ color: Color) -> some View {
      VStack(spacing: 2) {
        Text(key).font(.system(size: 22, weight: .black, design: .rounded))
        Text(label).font(.system(size: 12, weight: .bold, design: .rounded))
      }
      .foregroundStyle(ink)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(color, in: .rect(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(ink, lineWidth: 2))
      .shadow(color: ink, radius: 0, x: 0, y: 3)
    }
  }

  /// Aging as a blob that grows and warms up.
  struct Blob: View {
    let progress: Double

    var body: some View {
      Circle()
        .fill(progress >= 1 ? coral : sun.opacity(0.3 + 0.7 * progress))
        .frame(width: 10 + 8 * progress, height: 10 + 8 * progress)
        .overlay(Circle().stroke(ink, lineWidth: 1.5))
        .frame(width: 20, height: 20)
    }
  }
}
