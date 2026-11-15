import SwiftUI

/// The **several-at-once** counterpart to `SearchablePickerList`: pushed, `.searchable`, a checkmark per
/// chosen row. First used for a set's songs (ADR 0299).
///
/// **A tap toggles and the list stays.** Picking several things is the point, so popping on the first
/// tap, as the single-select list does, would mean coming back once per song. The way out is the back
/// button, and every tap has already committed, so there is no Done to forget.
struct SearchableMultiPickerList<Value: Hashable>: View {
    let title: String
    let items: [PickerItem<Value>]
    @Binding var selection: Set<Value>
    var tint: Color = PocketColor.practice

    @State private var query = ""

    private var filtered: [PickerItem<Value>] { PickerSearch.filter(items, query: query) }

    var body: some View {
        List {
            Section {
                ForEach(filtered) { item in
                    Button { toggle(item.value) } label: {
                        OptionRow(title: item.title, context: item.context,
                                  isSelected: selection.contains(item.value), tint: tint)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(PocketColor.background)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        // In the navigation bar, as the single-select list puts it: iOS 26's default placement sits
        // at the bottom, under anything inset there.
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

    private func toggle(_ value: Value) {
        if selection.contains(value) { selection.remove(value) } else { selection.insert(value) }
        haptic(.light)
    }
}
