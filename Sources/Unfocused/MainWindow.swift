import SwiftUI
import UnfocusedCore

/// The sections of the main window, grouped in its sidebar like System Settings.
enum AppSection: String, CaseIterable, Identifiable {
  case loops
  case people
  case recap
  case activity

  var id: String { rawValue }

  var title: String {
    switch self {
    case .loops: "Loops"
    case .people: "People"
    case .recap: "Recap"
    case .activity: "Activity"
    }
  }

  var systemImage: String {
    switch self {
    case .loops: "circle.dashed"
    case .people: "person.2"
    case .recap: "text.badge.checkmark"
    case .activity: "clock"
    }
  }

  /// Sidebar groups: the work itself, then looking back at it.
  static let groups: [(title: String, sections: [AppSection])] = [
    ("Work", [.loops, .people]),
    ("Look back", [.recap, .activity]),
  ]
}

/// One window for everything except Settings: a sidebar to move between the sections.
struct MainWindow: View {
  let model: AppModel
  @ObservedObject var app: AppDelegate

  var body: some View {
    NavigationSplitView {
      List(selection: $app.section) {
        ForEach(AppSection.groups, id: \.title) { group in
          Section(group.title) {
            ForEach(group.sections) { section in
              Label(section.title, systemImage: section.systemImage).tag(section)
            }
          }
        }
      }
      .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
    } detail: {
      switch app.section ?? .loops {
      case .loops: LoopsWindow(model: model)
      case .people: PeopleWindow(model: model)
      case .recap: RecapWindow(model: model)
      case .activity: ActivityWindow(model: model)
      }
    }
    .frame(minWidth: 900, minHeight: 520)
    // The app's own tint, not the system accent (a red accent made normal actions look like errors).
    .tint(Style.brand)
  }
}
