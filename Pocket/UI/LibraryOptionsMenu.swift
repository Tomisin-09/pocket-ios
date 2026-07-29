import SwiftUI

/// The **list options** control shared by the three practice libraries — one fixed-width toolbar
/// item holding the sort key, the sort direction, the favourites filter, and (on Routines) the
/// screen's non-primary action.
///
/// It exists to fix a chrome bug, not just to deduplicate. Exercises previously carried *two*
/// `.topBarLeading` items — a sort control that renders as a text pill (`↑ Recently Added`) plus a
/// favourites star — behind the system back button. With `.navigationBarTitleDisplayMode(.inline)`
/// iOS centres the title in what's left after the bar-button groups, so a fat leading group shoved
/// "Exercises" right of centre, and the title **moved** whenever the sort key changed, because the
/// pill's width tracks the key's label. Collapsing to one icon makes the group fixed-width; putting
/// it **trailing** balances it against the back button, which is the only leading item now.
///
/// The active sort key is still legible — it's the checkmarked row inside the menu — and an active
/// favourites filter shows on the bar as the filled variant of the icon, without changing its width.
///
/// The grammar this establishes, and which all three libraries follow: **leading is where you came
/// from; trailing is what you can do here** — list options first, then the screen's primary action.
struct LibraryOptionsMenu<Actions: View, SortControls: View>: View {
    /// The favourites filter (ADR 0119), rendered as a checkmarked toggle inside the menu.
    @Binding var favoritesOnly: Bool
    /// Hidden when the list has nothing to filter, matching the old per-screen gate.
    var showsFavoritesFilter = true
    var tint: Color = PocketColor.practice
    /// The screen's secondary actions, shown in their own section above the list options.
    @ViewBuilder var actions: Actions
    /// The sort pickers — `LibrarySortPickers`, or nothing on a library with a fixed order.
    @ViewBuilder var sortControls: SortControls

    var body: some View {
        Menu {
            Section { actions }
            Section {
                sortControls
                if showsFavoritesFilter {
                    Toggle(isOn: $favoritesOnly) {
                        Label("Favourites only", systemImage: favoritesOnly ? "star.fill" : "star")
                    }
                }
            }
        } label: {
            Image(systemName: favoritesOnly ? "ellipsis.circle.fill" : "ellipsis.circle")
        }
        .tint(tint)
        .accessibilityLabel(favoritesOnly ? "List options, showing favourites only" : "List options")
    }
}

extension LibraryOptionsMenu where Actions == EmptyView {
    /// A library whose menu holds only list options (Exercises, Loops).
    init(favoritesOnly: Binding<Bool>,
         showsFavoritesFilter: Bool = true,
         tint: Color = PocketColor.practice,
         @ViewBuilder sortControls: () -> SortControls) {
        self.init(favoritesOnly: favoritesOnly, showsFavoritesFilter: showsFavoritesFilter,
                  tint: tint, actions: { EmptyView() }, sortControls: sortControls)
    }
}

extension LibraryOptionsMenu where SortControls == EmptyView {
    /// A library with a fixed order (Routines — newest first), so only actions and the filter.
    init(favoritesOnly: Binding<Bool>,
         showsFavoritesFilter: Bool = true,
         tint: Color = PocketColor.practice,
         @ViewBuilder actions: () -> Actions) {
        self.init(favoritesOnly: favoritesOnly, showsFavoritesFilter: showsFavoritesFilter,
                  tint: tint, actions: actions, sortControls: { EmptyView() })
    }
}

/// The sort key + direction pickers, as menu sections. Split out so `LibraryOptionsMenu` doesn't
/// have to be generic over the key type when a library has no sort axis.
struct LibrarySortPickers<Key: LibrarySortKey>: View where Key.AllCases: RandomAccessCollection {
    @Binding var sortKey: Key
    @Binding var ascending: Bool

    var body: some View {
        Picker("Sort by", selection: $sortKey) {
            ForEach(Key.allCases) { key in
                Text(key.label).tag(key)
            }
        }
        Picker("Order", selection: $ascending) {
            Label("Ascending", systemImage: "arrow.up").tag(true)
            Label("Descending", systemImage: "arrow.down").tag(false)
        }
    }
}
