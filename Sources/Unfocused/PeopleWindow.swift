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
  @State private var deleting: Person?
  @State private var newName = ""

  var body: some View {
    // A plain split (not NavigationSplitView): this view sits inside the main window's sidebar
    // layout, and navigation split views don't nest.
    HSplitView {
      List(model.people, selection: $selectedID) { person in
        let open = model.loops(involving: person).filter { $0.state == .open }.count
        HStack {
          Text(person.name)
          Spacer()
          if open > 0 {
            Text("\(open) open").font(.caption).monospacedDigit().foregroundStyle(.secondary)
          }
        }
        .contextMenu { personMenu(person) }
      }
      .safeAreaInset(edge: .top) {
        Text("Who your Loops involve: people waiting on you, and people you're waiting on.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
      }
      .overlay {
        if model.people.isEmpty {
          ContentUnavailableView {
            Label("No People yet", systemImage: "person.2")
          } description: {
            Text(
              "People are who your Loops involve: someone waiting on you, or someone you're waiting on. "
                + "Import a list of names, or type @name when capturing a Loop."
            )
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
    .confirmationDialog(
      "Delete \(deleting?.name ?? "")?",
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    ) {
      Button("Delete", role: .destructive) {
        if let deleting { model.delete(deleting) }
      }
    } message: {
      Text("They're removed from every Loop they're on. The Loops stay. This can't be undone.")
    }
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
    Button("Delete…", role: .destructive) { deleting = person }
  }
}

private struct PersonDetail: View {
  let model: AppModel
  let person: Person

  var body: some View {
    let loops = model.loops(involving: person)
    let direction: (Loop) -> Direction? = { loop in
      model.involvements(of: loop).first { $0.person.id == person.id }?.direction
    }
    let open = loops.filter { $0.state == .open }
    let owed = open.filter { direction($0) == .owed }
    let waiting = open.filter { direction($0) == .waiting }
    let finished = loops.filter { $0.state != .open }
    Form {
      Section {
        Text(person.name).font(.title2)
        if open.isEmpty {
          Text("Nothing open with \(person.name).").foregroundStyle(.secondary)
        }
      }
      loopSection(
        "They're waiting on you",
        systemImage: "arrow.left",
        footer: "Owed: you have something to deliver.",
        owed
      )
      loopSection(
        "You're waiting on them",
        systemImage: "arrow.right",
        footer:
          "Waiting: these come back as \"Follow up with \(person.name)?\" once they've been quiet for a few active days.",
        waiting
      )
      if !finished.isEmpty {
        Section("Closed or let go") {
          ForEach(finished) { loop in
            LabeledContent(loop.title) { Text(loop.state.label).foregroundStyle(.secondary) }
          }
        }
      }
    }
    .formStyle(.grouped)
  }

  @ViewBuilder private func loopSection(
    _ title: String,
    systemImage: String,
    footer: String,
    _ loops: [Loop]
  ) -> some View {
    if !loops.isEmpty {
      Section {
        ForEach(loops) { loop in
          HStack {
            AgingMark(aging: model.aging[loop.id])
            Text(loop.title)
            Spacer()
            Button("Edit…") { model.editLoop?(loop) }.buttonStyle(.borderless)
          }
        }
      } header: {
        Label(title, systemImage: systemImage)
      } footer: {
        Text(footer).font(.caption).foregroundStyle(.secondary)
      }
    }
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
  /// Short, for chips: "Ada · waiting on me".
  var label: String { self == .owed ? "waiting on me" : "I'm waiting" }
  /// For pickers: the whole relationship in plain words.
  var choice: String { self == .owed ? "They're waiting on me" : "I'm waiting on them" }
  /// The glossary term behind it.
  var help: String {
    self == .owed ? "Owed: they're waiting on you" : "Waiting: you're waiting on them; it comes back as a follow-up"
  }
}

extension LoopState {
  var label: String {
    switch self {
    case .open: "Open"
    case .closed: "Closed"
    case .letGo: "Let go"
    }
  }
}
