import SwiftUI

/// The Toolkit **Glossary** (ADR 0096 Slice 1) — a searchable, plain-language reference of the chord,
/// scale and theory terms a player meets across Pocket. Static in-house content (`GlossaryTerm.all`);
/// no audio, no state, no dependencies, which is why it anchors the audio-free Slice 1 (ADR 0096 D4/D5).
///
/// Grouped by area, filtered live by the search field. Content states objective identity only — a
/// glossary informs, it never grades the player (ADR 0070).
struct GlossaryView: View {
    @State private var query = ""

    /// Terms matching the current query, grouped into their areas in declaration order — empty areas
    /// drop out so a search only shows sections that have hits.
    private var sections: [(area: GlossaryTerm.Area, terms: [GlossaryTerm])] {
        let matches = GlossaryTerm.matching(query)
        return GlossaryTerm.Area.allCases.compactMap { area in
            let terms = matches.filter { $0.area == area }
            return terms.isEmpty ? nil : (area, terms)
        }
    }

    var body: some View {
        List {
            if sections.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ForEach(sections, id: \.area) { section in
                    Section(section.area.rawValue) {
                        ForEach(section.terms) { term in
                            row(for: term)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Glossary")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search terms")
        .autocorrectionDisabled()
        .tint(PocketColor.toolkit)
    }

    private func row(for term: GlossaryTerm) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(term.term)
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
            Text(term.definition)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .listRowBackground(PocketColor.surfaceStandard)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Glossary") {
    NavigationStack { GlossaryView() }
        .preferredColorScheme(.dark)
}
