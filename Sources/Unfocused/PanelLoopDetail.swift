import SwiftUI
import UnfocusedCore

/// The right side of the panel: what you need to get back into the selected Loop.
struct PanelLoopDetail: View {
  let model: AppModel
  let loop: Loop
  /// The Focused Loop filling the panel: a larger title.
  var prominent = false
  /// Keys that act on this Loop, shown with it rather than in the panel's footer.
  var actions: [String] = []

  var body: some View {
    let aging = model.aging[loop.id]
    let lastWorked = model.lastEngagement(of: loop)
    let lastSeen = model.workLog(for: loop).first
    let people = model.involvements(of: loop)
    let anchors = model.anchors(of: loop)
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 4) {
          Text(loop.title).font(prominent ? .system(size: 28, weight: .semibold) : .title3.weight(.semibold))
            .lineLimit(3)
          Text(when(lastWorked: lastWorked)).font(.callout).foregroundStyle(.secondary)
          LooseEndNote(aging: aging)
        }

        if !actions.isEmpty {
          KeyHints(items: actions, footer: false)
        }

        whereILeftOff

        if let lastSeen {
          Label {
            Text("Last seen in \(lastSeen.anchor.title) · \(Style.relative(lastSeen.end))")
              .lineLimit(2)
          } icon: {
            Image(systemName: "clock.arrow.circlepath")
          }
          .font(.callout)
          .foregroundStyle(.secondary)
        }

        if !people.isEmpty {
          HStack(spacing: 6) {
            ForEach(people, id: \.person.id) { involvement in
              Label(
                "\(involvement.person.name) · \(involvement.direction.label)",
                systemImage: involvement.direction == .owed ? "arrow.left" : "arrow.right"
              )
              .font(.caption)
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(.quaternary, in: Capsule())
              .help(involvement.direction.help)
            }
          }
        }

        if !anchors.isEmpty {
          VStack(alignment: .leading, spacing: 4) {
            Text(anchors.count == 1 ? "Anchor" : "Anchors").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            ForEach(Array(anchors.prefix(3).enumerated()), id: \.offset) { _, anchor in
              Button {
                AnchorOpener.open(anchor)
              } label: {
                HStack(spacing: 8) {
                  AppIcon(bundleID: anchor.source.bundleID)
                  Text(anchor.title).lineLimit(1)
                  Image(systemName: "arrow.up.forward").font(.caption2).foregroundStyle(.tertiary)
                }
                .font(.callout)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .help("Open")
            }
          }
        }
      }
      .padding(22)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder private var whereILeftOff: some View {
    if let note = loop.whereILeftOff {
      VStack(alignment: .leading, spacing: 6) {
        Label("Where I left off", systemImage: "bookmark").font(.caption.weight(.medium)).foregroundStyle(.secondary)
        Text(note).font(.body).fixedSize(horizontal: false, vertical: true)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(RoundedRectangle(cornerRadius: Style.rowRadius).fill(.quaternary.opacity(0.6)))
    } else {
      Text("No note yet. You'll be asked where you left off when you leave it.")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
  }

  private func when(lastWorked: Date?) -> String {
    if let lastWorked {
      return "Last worked on \(Style.relative(lastWorked))"
    }
    return "Captured \(Style.relative(loop.capturedAt)), not worked on yet"
  }
}
