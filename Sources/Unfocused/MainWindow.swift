import SwiftUI
import UnfocusedCore

/// The sections of the main window, grouped in its sidebar like System Settings.
enum AppSection: String, CaseIterable, Identifiable {
  case loops
  case people
  case recap
  case activity
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .loops: "Loops"
    case .people: "People"
    case .recap: "Recap"
    case .activity: "Activity"
    case .settings: "Settings"
    }
  }

  var systemImage: String {
    switch self {
    case .loops: "circle.dashed"
    case .people: "person.2"
    case .recap: "text.badge.checkmark"
    case .activity: "clock"
    case .settings: "gearshape"
    }
  }

  /// Sidebar groups: the work itself, looking back at it, then how the app behaves.
  static let groups: [(title: String, sections: [AppSection])] = [
    ("Work", [.loops, .people]),
    ("Look back", [.recap, .activity]),
    ("App", [.settings]),
  ]
}

/// One window for everything, Settings included: a sidebar to move between the sections.
struct MainWindow: View {
  let model: AppModel
  @ObservedObject var app: AppDelegate

  var body: some View {
    NavigationSplitView {
      // Our own rows, not a List: List selection follows the system accent (red on some Macs).
      ScrollView {
        VStack(alignment: .leading, spacing: 2) {
          ForEach(AppSection.groups, id: \.title) { group in
            Text(group.title)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 10)
              .padding(.top, 14)
              .padding(.bottom, 4)
            ForEach(group.sections) { section in
              let selected = (app.section ?? .loops) == section
              Button {
                app.section = section
              } label: {
                Label {
                  Text(section.title).foregroundStyle(.primary)
                } icon: {
                  Image(systemName: section.systemImage)
                    .foregroundStyle(selected ? AnyShapeStyle(Style.brand) : AnyShapeStyle(.secondary))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Style.rowBackground(selected: selected))
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
            }
          }
        }
        .padding(.horizontal, 10)
      }
      .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
    } detail: {
      switch app.section ?? .loops {
      case .loops: LoopsWindow(model: model)
      case .people: PeopleWindow(model: model)
      case .recap: RecapWindow(model: model)
      case .activity: ActivityWindow(model: model)
      case .settings: SettingsView(model: model, reminder: app.reminder)
      }
    }
    .frame(minWidth: 900, minHeight: 520)
    // The app's own tint, not the system accent (a red accent made normal actions look like errors).
    .tint(Style.brand)
  }
}
