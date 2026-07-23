import SwiftData
import SwiftUI

/// A reusable **link-authoring picker** (ADR 0111) — a `.searchable` list of candidate models a
/// user toggles on/off to build a relationship, mirroring `SkillPickerSheet`'s toggle-row idiom.
/// Used both ways: pick the songs an exercise is *for* (`Exercise.linkedSongs`) and the drills that
/// serve a song (`Song.linkedExercises`). Deliberately **presentation-only** — the owning detail
/// sheet supplies the candidates and the `isLinked`/`toggle` closures, so all persistence (mutating
/// the relationship + `save()`) stays in one place on the model side. Toggling is live: a checkmark
/// links, tapping a linked row unlinks, and the caller's view observing the `@Model` refreshes both
/// the row and the section behind the sheet.
struct LinkPickerSheet<Item: PersistentModel>: View {
    let title: String
    let prompt: String
    let emptyCatalog: String
    /// Every candidate of this type (already sorted by the caller's `@Query`).
    let candidates: [Item]
    let label: (Item) -> String
    let subtitle: (Item) -> String?
    let isLinked: (Item) -> Bool
    let toggle: (Item) -> Void
    let accent: Color

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if candidates.isEmpty {
                    emptyState(emptyCatalog)
                } else {
                    let matches = filtered
                    if matches.isEmpty {
                        emptyState("Nothing matches “\(query)”.")
                    } else {
                        ForEach(matches, id: \.persistentModelID) { item in
                            row(item)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .searchable(text: $query, prompt: prompt)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.futura(.body, weight: .bold))
                        .tint(accent)
                }
            }
        }
    }

    /// Case/diacritic-insensitive match over the row's label and its optional subtitle, so a song is
    /// findable by artist and an exercise by template — mirroring the app's other search fields.
    private var filtered: [Item] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return candidates }
        return candidates.filter { item in
            let haystack = [label(item), subtitle(item) ?? ""].joined(separator: " ")
            return haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private func row(_ item: Item) -> some View {
        let linked = isLinked(item)
        return Button {
            toggle(item)
            haptic(.light)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label(item))
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                    if let subtitle = subtitle(item), !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: linked ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(linked ? accent : PocketColor.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(PocketColor.background)
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.futura(.footnote))
            .foregroundStyle(PocketColor.textSecondary)
            .listRowBackground(PocketColor.background)
    }
}
