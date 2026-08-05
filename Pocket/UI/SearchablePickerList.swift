import SwiftUI

/// An **unbounded** selection list — pushed, `.searchable`, with an optional clearing row.
///
/// The counterpart to `OptionListSection`, for the case where the choices come from the player's own
/// library rather than from a fixed set. A popup `Menu` cannot serve that at all: it has no search,
/// no titles longer than a line, and it grows without limit, so it works on the day the library holds
/// four songs and is unusable on the day it holds forty. Being *pushed* rather than presented also
/// keeps the caller's own edits on screen behind it — you come back to the form you left.
///
/// Selection commits on tap and pops immediately. There is no Done button, because a single-select
/// list with a checkmark has nothing left to confirm.
struct SearchablePickerList<Value: Hashable>: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let items: [PickerItem<Value>]
    /// Label for the row that clears the selection — `nil` for a picker that must return something.
    var clearLabel: String?
    @Binding var selection: Value?
    var tint: Color = PocketColor.practice

    @State private var query = ""

    private var filtered: [PickerItem<Value>] { PickerSearch.filter(items, query: query) }

    var body: some View {
        List {
            // The clearing row is hidden while searching: it matches no query, and leaving it pinned
            // above the results would make an empty search look like it found one thing.
            if let clearLabel, query.trimmingCharacters(in: .whitespaces).isEmpty {
                Section {
                    Button { choose(nil) } label: {
                        OptionRow(title: clearLabel, isSelected: selection == nil, tint: tint)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(PocketColor.background)
                }
            }
            Section {
                ForEach(filtered) { item in
                    Button { choose(item.value) } label: {
                        OptionRow(title: item.title, context: item.context,
                                  isSelected: item.value == selection, tint: tint)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(PocketColor.background)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search \(title.lowercased())")
        .overlay {
            // A search that matches nothing must say so. An empty list reads as a broken library.
            if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func choose(_ value: Value?) {
        selection = value
        haptic(.light)
        dismiss()
    }
}
