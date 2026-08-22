import SwiftUI

/// The **list options** control shared by the three practice libraries — one fixed-width toolbar
/// item holding the sort key, the sort direction, the favourites filter, and (on Routines) the
/// screen's non-primary action.
///
/// The `SortControls == EmptyView` overload this used to carry — "a library with a fixed order
/// (Routines)" — went with ADR 0178, which gave Routines a sort and left no library without one.
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
    /// An optional filter that **widens** the list past its default gate, rather than narrowing it
    /// like Favourites — the Loops library's "Show all loops" (ADR 0138 G4), the deliberate way to
    /// reach an unmeasured loop. `nil` on libraries whose default list already shows everything, and
    /// it sits beside Favourites because it is a filter, not one of the screen's actions.
    var widenFilter: Binding<Bool>?
    var widenFilterLabel = "Show all"
    /// A second **narrowing** filter, beside Favourites — the Loops library's "Backing tracks only"
    /// (ADR 0135 B4), the cross-song *jam over something* shelf the per-song browse can't give. `nil`
    /// on libraries with nothing but Favourites to narrow by.
    var narrowFilter: Binding<Bool>?
    var narrowFilterLabel = "Backing tracks only"
    /// The narrow filter's glyph, named without the `.fill` suffix — the active state appends it, the
    /// same way Favourites' star does.
    var narrowFilterImage = "guitars"
    var tint: Color = PocketColor.practice
    /// The screen's secondary actions, shown in their own section above the list options.
    @ViewBuilder var actions: Actions
    /// The sort pickers — `LibrarySortPickers`, or nothing on a library with a fixed order.
    @ViewBuilder var sortControls: SortControls

    /// Whether the list is showing something other than its default — the bar icon fills so an active
    /// filter is legible without the menu open, and without the icon changing width (the whole point
    /// of this control). Any filter counts: all of them change what the list is showing.
    private var isFiltered: Bool {
        favoritesOnly || widenFilter?.wrappedValue == true || narrowFilter?.wrappedValue == true
    }

    private var accessibilityLabel: String {
        if favoritesOnly { return "List options, showing favourites only" }
        if narrowFilter?.wrappedValue == true { return "List options, \(narrowFilterLabel.lowercased())" }
        if widenFilter?.wrappedValue == true { return "List options, \(widenFilterLabel.lowercased())" }
        return "List options"
    }

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
                if let narrowFilter {
                    Toggle(isOn: narrowFilter) {
                        Label(narrowFilterLabel,
                              systemImage: narrowFilter.wrappedValue ? "\(narrowFilterImage).fill"
                                                                     : narrowFilterImage)
                    }
                }
                if let widenFilter {
                    Toggle(isOn: widenFilter) {
                        Label(widenFilterLabel,
                              systemImage: widenFilter.wrappedValue ? "line.3.horizontal.decrease.circle.fill"
                                                                    : "line.3.horizontal.decrease.circle")
                    }
                }
            }
        } label: {
            Image(systemName: isFiltered ? "ellipsis.circle.fill" : "ellipsis.circle")
        }
        .tint(tint)
        .accessibilityLabel(accessibilityLabel)
    }
}

extension LibraryOptionsMenu where Actions == EmptyView {
    /// A library whose menu holds only list options (Exercises, Loops).
    init(favoritesOnly: Binding<Bool>,
         showsFavoritesFilter: Bool = true,
         widenFilter: Binding<Bool>? = nil,
         widenFilterLabel: String = "Show all",
         narrowFilter: Binding<Bool>? = nil,
         narrowFilterLabel: String = "Backing tracks only",
         narrowFilterImage: String = "guitars",
         tint: Color = PocketColor.practice,
         @ViewBuilder sortControls: () -> SortControls) {
        self.init(favoritesOnly: favoritesOnly, showsFavoritesFilter: showsFavoritesFilter,
                  widenFilter: widenFilter, widenFilterLabel: widenFilterLabel,
                  narrowFilter: narrowFilter, narrowFilterLabel: narrowFilterLabel,
                  narrowFilterImage: narrowFilterImage,
                  tint: tint, actions: { EmptyView() }, sortControls: sortControls)
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
