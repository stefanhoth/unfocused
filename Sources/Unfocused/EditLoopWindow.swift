import AppKit
import SwiftUI
import UnfocusedCore

/// Opens "Edit Loop": one place for a Loop's title, Where I left off, People and Anchors.
@MainActor
final class EditLoopController {
  private let model: AppModel
  private var window: NSWindow?

  init(model: AppModel) {
    self.model = model
  }

  func show(_ loop: Loop) {
    let window = window ?? makeWindow()
    self.window = window
    window.contentView = NSHostingView(
      rootView: EditLoopView(model: model, loopID: loop.id, close: { [weak window] in window?.close() })
    )
    window.title = "Edit Loop"
    window.center()
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }

  private func makeWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.isReleasedWhenClosed = false
    return window
  }
}

struct EditLoopView: View {
  let model: AppModel
  let loopID: UUID
  let close: () -> Void

  @State private var title = ""
  @State private var note = ""
  @State private var newPerson = ""

  var body: some View {
    if let loop = model.loop(loopID) {
      Form {
        Section {
          TextField("Title", text: $title)
            .font(.title3)
            .onSubmit { model.retitle(loop, to: title) }
          TextField(
            "Where I left off",
            text: $note,
            prompt: Text("Where you left off, to get back in quickly"),
            axis: .vertical
          )
          .lineLimit(2...4)
          .onSubmit { model.setWhereILeftOff(loop, to: note) }
        }

        people(of: loop)
        anchors(of: loop)
      }
      .formStyle(.grouped)
      .safeAreaInset(edge: .bottom) {
        HStack {
          Text("Changes are saved as you go.").font(.caption).foregroundStyle(.secondary)
          Spacer()
          Button("Done") {
            save(loop)
            close()
          }
          .keyboardShortcut(.cancelAction)
          .buttonStyle(.borderedProminent)
        }
        .padding(16)
      }
      .frame(minWidth: 520, minHeight: 520)
      .tint(Style.brand)
      .onAppear {
        title = loop.title
        note = loop.whereILeftOff ?? ""
      }
      .onDisappear { save(loop) }
    } else {
      ContentUnavailableView("This Loop is gone", systemImage: "questionmark.circle")
    }
  }

  private func save(_ loop: Loop) {
    if title != loop.title { model.retitle(loop, to: title) }
    if note != (loop.whereILeftOff ?? "") { model.setWhereILeftOff(loop, to: note) }
  }

  // MARK: People

  @ViewBuilder private func people(of loop: Loop) -> some View {
    let involved = model.involvements(of: loop)
    Section {
      ForEach(involved, id: \.person.id) { involvement in
        HStack {
          Text(involvement.person.name)
          Spacer()
          Picker(
            "Direction",
            selection: Binding(
              get: { involvement.direction },
              set: { model.setDirection($0, of: involvement.person, in: loop) }
            )
          ) {
            ForEach(Direction.allCases, id: \.self) { Text($0.choice).tag($0) }
          }
          .labelsHidden()
          .fixedSize()
          Button("Remove") { model.remove(involvement.person, from: loop) }
            .buttonStyle(.borderless)
        }
      }
      TextField("Add a Person", text: $newPerson, prompt: Text("Add a Person: type a name"))
        .onSubmit { add(newPerson, to: loop) }
      let suggestions = suggestions(for: loop, involved: involved)
      if !suggestions.isEmpty {
        HStack {
          ForEach(suggestions) { person in
            Button(person.name) { add(person.name, to: loop) }
              .buttonStyle(.bordered)
              .controlSize(.small)
          }
        }
      }
    } header: {
      Text("People")
    } footer: {
      Text(
        "\"They're waiting on me\" (Owed) means you have something to deliver. \"I'm waiting on them\" (Waiting) "
          + "comes back as \"Follow up with …?\" once it's been quiet for a few active days."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  private func suggestions(for loop: Loop, involved: [Involvement]) -> [Person] {
    let typed = newPerson.trimmingCharacters(in: .whitespaces)
    guard !typed.isEmpty else { return [] }
    let ids = Set(involved.map(\.person.id))
    return Array(model.searchPeople(typed).filter { !ids.contains($0.id) }.prefix(4))
  }

  private func add(_ name: String, to loop: Loop) {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    model.involve(named: trimmed, in: loop)
    newPerson = ""
  }

  // MARK: Anchors

  @ViewBuilder private func anchors(of loop: Loop) -> some View {
    let anchors = model.anchors(of: loop)
    Section {
      if anchors.isEmpty {
        Text("No Anchors yet. Capture, or ⌥↩ in the panel, adds the window you're on.")
          .foregroundStyle(.secondary)
      }
      ForEach(Array(anchors.enumerated()), id: \.element.identifier) { _, anchor in
        AnchorRow(model: model, loop: loop, anchor: anchor)
      }
    } header: {
      Text("Anchors")
    } footer: {
      Text("Where the work lives. Renaming only changes how it's shown; it still opens the same spot.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

private struct AnchorRow: View {
  let model: AppModel
  let loop: Loop
  let anchor: UnfocusedCore.Anchor
  @State private var title = ""

  var body: some View {
    HStack(spacing: 8) {
      AppIcon(bundleID: anchor.source.bundleID)
      TextField("Title", text: $title)
        .textFieldStyle(.plain)
        .onSubmit { model.renameAnchor(anchor, of: loop, to: title) }
      Button("Open") { AnchorOpener.open(anchor) }
        .buttonStyle(.borderless)
      Button("Remove") { model.removeAnchor(anchor, from: loop) }
        .buttonStyle(.borderless)
    }
    .onAppear { title = anchor.title }
    .onDisappear { if title != anchor.title { model.renameAnchor(anchor, of: loop, to: title) } }
  }
}
