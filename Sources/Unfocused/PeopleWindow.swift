import AppKit
import SwiftUI
import UnfocusedCore
import UniformTypeIdentifiers

/// Everyone unfocused knows, with their Loops, plus importing a list of names.
struct PeopleWindow: View {
  let model: AppModel

  @State private var selectedID: Person.ID?
  @State private var importing = false
  @State private var renaming: Person?
  @State private var newName = ""

  var body: some View {
    // A plain split (not NavigationSplitView): this view sits inside the main window's sidebar
    // layout, and navigation split views don't nest.
    HSplitView {
      List(model.people, selection: $selectedID) { person in
        Text(person.name)
          .contextMenu { personMenu(person) }
      }
      .overlay {
        if model.people.isEmpty {
          ContentUnavailableView {
            Label("No People yet", systemImage: "person.2")
          } description: {
            Text("Import a list of names, or type @name when capturing a Loop.")
          } actions: {
            Button("Import Names…") { importing = true }
          }
        }
      }
      .frame(minWidth: 220, idealWidth: 260, maxWidth: 440)
      .toolbar {
        Button("Import Names…", systemImage: "square.and.arrow.down") { importing = true }
      }
      Group {
        if let person = model.people.first(where: { $0.id == selectedID }) {
          PersonDetail(model: model, person: person)
        } else {
          Text("Select a Person").foregroundStyle(.secondary)
        }
      }
      .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(minWidth: 640, minHeight: 380)
    .navigationTitle("People")
    .onAppear { model.refresh() }
    .sheet(isPresented: $importing) { ImportPeopleSheet(model: model) }
    .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
      TextField("Name", text: $newName)
      Button("Rename") {
        if let renaming { model.rename(renaming, to: newName) }
      }
      Button("Cancel", role: .cancel) {}
    }
  }

  @ViewBuilder private func personMenu(_ person: Person) -> some View {
    Button("Rename…") {
      newName = person.name
      renaming = person
    }
    Menu("Merge Into") {
      ForEach(model.people.filter { $0.id != person.id }) { other in
        Button(other.name) { model.merge(person, into: other) }
      }
    }
    Divider()
    Button("Delete", role: .destructive) { model.delete(person) }
  }
}

private struct PersonDetail: View {
  let model: AppModel
  let person: Person

  var body: some View {
    let loops = model.loops(involving: person)
    Form {
      Section {
        Text(person.name).font(.title2)
      }
      Section("Loops") {
        if loops.isEmpty {
          Text("Not on any Loop yet.").foregroundStyle(.secondary)
        }
        ForEach(loops) { loop in
          let direction = model.involvements(of: loop).first { $0.person.id == person.id }?.direction
          LabeledContent {
            Text(direction.map(\.label) ?? "")
          } label: {
            Text(loop.title)
            Text(loop.state.label).font(.caption).foregroundStyle(.secondary)
          }
        }
      }
    }
    .formStyle(.grouped)
  }
}

/// Paste names, or drop/choose a .txt or .csv file. Near-duplicates are decided one by one.
private struct ImportPeopleSheet: View {
  let model: AppModel
  @Environment(\.dismiss) private var dismiss

  @State private var text = ""
  @State private var result: PeopleImport?
  @State private var decided: Set<String> = []

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Import Names").font(.title2)
      if let result {
        resultView(result)
      } else {
        Text("Paste one name per line, or drop a .txt or .csv file (the first column is used).")
          .foregroundStyle(.secondary)
        TextEditor(text: $text)
          .font(.body.monospaced())
          .frame(minHeight: 220)
          .border(.separator)
          .dropDestination(for: URL.self) { urls, _ in
            text += urls.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
            return true
          }
      }
      HStack {
        if result == nil {
          Button("Choose File…") { chooseFile() }
        }
        Spacer()
        Button(result == nil ? "Cancel" : "Done") { dismiss() }
          .keyboardShortcut(.cancelAction)
        if result == nil {
          Button("Import") { result = model.importPeople(text) }
            .keyboardShortcut(.defaultAction)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
    .padding(20)
    .frame(width: 480)
  }

  @ViewBuilder private func resultView(_ result: PeopleImport) -> some View {
    Text("Added \(result.added.count). Skipped \(result.skippedDuplicates) already known.")
    let open = result.nearMatches.filter { !decided.contains($0.name) }
    if !open.isEmpty {
      Text("These look like People you already have:").font(.headline)
      ForEach(open, id: \.name) { match in
        HStack {
          Text("\(match.name) ↔ \(match.existing.name)")
          Spacer()
          Button("Same Person") { decided.insert(match.name) }
          Button("Different") {
            model.keepAsNewPerson(match.name)
            decided.insert(match.name)
          }
        }
      }
    }
  }

  private func chooseFile() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.plainText, .commaSeparatedText]
    panel.allowsMultipleSelection = true
    guard panel.runModal() == .OK else { return }
    text += panel.urls.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
  }
}

extension Direction {
  var label: String { self == .owed ? "Owed" : "Waiting" }
  var help: String { self == .owed ? "They're waiting on you" : "You're waiting on them" }
}

extension LoopState {
  var label: String {
    switch self {
    case .open: "Open"
    case .closed: "Closed"
    case .dropped: "Dropped"
    }
  }
}
