import SwiftUI

/// A list with unfocused's own selection: the quiet neutral highlight from `Style.rowBackground`
/// instead of macOS's selection color, which follows the system accent and can't be tinted.
/// ↑/↓ move the selection while the list has keyboard focus.
struct SelectableList<Item: Identifiable, Header: View, Row: View>: View {
  let items: [Item]
  @Binding var selection: Item.ID?
  @ViewBuilder var header: () -> Header
  @ViewBuilder var row: (Item) -> Row
  @FocusState private var focused: Bool

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 2) {
          header()
          ForEach(items) { item in
            row(item)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(Style.rowBackground(selected: item.id == selection))
              .contentShape(Rectangle())
              .onTapGesture {
                selection = item.id
                focused = true
              }
              .id(item.id)
          }
        }
        .padding(10)
      }
      .focusable()
      .focusEffectDisabled()
      .focused($focused)
      .onKeyPress(.downArrow) { move(1, proxy) }
      .onKeyPress(.upArrow) { move(-1, proxy) }
    }
  }

  private func move(_ step: Int, _ proxy: ScrollViewProxy) -> KeyPress.Result {
    guard !items.isEmpty else { return .ignored }
    let index = items.firstIndex { $0.id == selection }.map { $0 + step } ?? (step > 0 ? 0 : items.count - 1)
    let clamped = min(max(index, 0), items.count - 1)
    selection = items[clamped].id
    proxy.scrollTo(items[clamped].id)
    return .handled
  }
}

extension SelectableList where Header == EmptyView {
  init(items: [Item], selection: Binding<Item.ID?>, @ViewBuilder row: @escaping (Item) -> Row) {
    self.init(items: items, selection: selection, header: { EmptyView() }, row: row)
  }
}
