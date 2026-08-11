import SwiftUI

/// The Toolkit **Help & FAQs** screen (ADR 0145) — the app's first in-app help, and the first place it
/// carries a support address. Static in-house content (`FAQEntry.all`); no audio, no state, no
/// dependencies, which is what lets it sit in the free Toolkit alongside the Glossary.
///
/// Built as `GlossaryView` with one difference: **each question expands its answer in place**. A
/// glossary definition is a line and can always be visible; an FAQ answer is a paragraph, and
/// seventeen of them stacked open is a wall rather than a list you can scan.
///
/// A non-empty search **force-expands every match** — the same rule `LibrarySectionExpansion` applies
/// while searching. Hunting a word and then having to tap each hit open to find out whether it's the
/// one you wanted is hostile, and search here matches inside answers precisely so it can find things
/// the questions don't say.
///
/// The expanding row is deliberately *not* `CollapsibleLibrarySection`: that component folds whole
/// sections and carries a `LibrarySectionExpansion` persistence payload this screen doesn't want (help
/// should open closed every time). Only its interaction grammar — light haptic, 0.2s ease, rotating
/// chevron — is reused, so the gesture feels the same in both places.
struct FAQView: View {
    @State private var query = ""
    /// Questions currently open, keyed on `FAQEntry.id`. Session-only on purpose — see the note above.
    @State private var expanded: Set<String> = []

    /// True while the player is searching, which is what forces matches open.
    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Entries matching the current query, grouped into their areas in declaration order — empty areas
    /// drop out so a search only shows sections that have hits.
    private var sections: [(area: FAQEntry.Area, entries: [FAQEntry])] {
        let matches = FAQEntry.matching(query)
        return FAQEntry.Area.allCases.compactMap { area in
            let entries = matches.filter { $0.area == area }
            return entries.isEmpty ? nil : (area, entries)
        }
    }

    var body: some View {
        List {
            if sections.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ForEach(sections, id: \.area) { section in
                    Section(section.area.rawValue) {
                        ForEach(section.entries) { entry in
                            row(for: entry)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Help & FAQs")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search help")
        .autocorrectionDisabled()
        .tint(PocketColor.toolkit)
    }

    private func row(for entry: FAQEntry) -> some View {
        let isOpen = isExpanded(entry)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                haptic(.light)
                withAnimation(.easeInOut(duration: 0.2)) { toggle(entry) }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.question)
                        .font(.futura(.headline))
                        .foregroundStyle(PocketColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.futura(.footnote, weight: .semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                Text(entry.answer)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    // The support address lives in one answer as the fallback for a device with no
                    // Mail account (ADR 0145) — it has to be selectable to be a fallback at all.
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(PocketColor.surfaceStandard)
        .accessibilityElement(children: .combine)
        .accessibilityHint(isOpen ? "Collapses this answer" : "Expands this answer")
    }

    /// Open while the player tapped it open, **or** while a search is running and this is a match —
    /// every visible row is a match by construction, so searching opens all of them.
    private func isExpanded(_ entry: FAQEntry) -> Bool {
        isSearching || expanded.contains(entry.id)
    }

    /// Tapping a force-expanded row still works: it writes the explicit set, so clearing the search
    /// leaves exactly the rows the player chose to keep open.
    private func toggle(_ entry: FAQEntry) {
        if expanded.contains(entry.id) {
            expanded.remove(entry.id)
        } else {
            expanded.insert(entry.id)
        }
    }
}

#Preview("Help & FAQs") {
    NavigationStack { FAQView() }
        .preferredColorScheme(.dark)
}

#Preview("Help & FAQs — searching") {
    NavigationStack { FAQView() }
}
