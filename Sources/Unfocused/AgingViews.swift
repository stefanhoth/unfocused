import SwiftUI
import UnfocusedCore

/// A small ring that fills as a Loop drifts toward a Loose End, then turns into a solid dot.
struct AgingMark: View {
  let aging: LoopAging?

  var body: some View {
    if let aging, aging.activeDaysWithoutEngagement > 0 {
      ZStack {
        Circle().stroke(.quaternary, lineWidth: 2)
        Circle()
          .trim(from: 0, to: aging.progress)
          .stroke(color(aging), style: StrokeStyle(lineWidth: 2, lineCap: .round))
          .rotationEffect(.degrees(-90))
        if aging.isLooseEnd { Circle().fill(color(aging)).padding(3) }
      }
      .frame(width: 12, height: 12)
      .help(help(aging))
      .animation(.easeOut, value: aging.progress)
    }
  }

  private func color(_ aging: LoopAging) -> Color {
    aging.isLooseEnd ? Style.looseEnd : Style.looseEnd.opacity(0.4 + 0.6 * aging.progress)
  }

  private func help(_ aging: LoopAging) -> String {
    let days = aging.activeDaysWithoutEngagement
    let untouched = "Untouched for \(days) active day\(days == 1 ? "" : "s")"
    return aging.isLooseEnd ? "Loose End. \(untouched)." : "\(untouched)."
  }
}

/// The line under a Loose End: who to follow up with, or how long it's been.
struct LooseEndNote: View {
  let aging: LoopAging?

  var body: some View {
    if let aging, aging.isLooseEnd {
      Group {
        if aging.followUp.isEmpty {
          Text("Loose End · untouched for \(aging.activeDaysWithoutEngagement) active days")
        } else {
          Text("Follow up with \(aging.followUp.map(\.name).formatted(.list(type: .or)))?")
        }
      }
      .font(.caption)
      .foregroundStyle(Style.looseEnd)
    }
  }
}
