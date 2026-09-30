import SwiftData
import SwiftUI

/// The **Toolkit** hub landing (ADR 0096 Slice 1) — the app's free, deterministic *reference*
/// destination, distinct from the exercise editors (which *author* practice content). Reached from the
/// fourth home card; relies on an ambient `NavigationStack` (pushed from Home, like `PracticeView` /
/// `LibraryView`) rather than owning one, so its sections push onto the home stack.
///
/// Slice 1 carried the first zero-dependency tenants (ADR 0096 D5): **My Chords** (the `SavedChord`
/// library promoted from the in-context menu to a full screen) and a static **Glossary**, joined by the
/// **Tuner** (ADR 0115) and now **Help & FAQs** (ADR 0145) — the same animal as the glossary, a static
/// catalog rendered by a thin screen, and the app's first in-app support path. **My Progressions**
/// (ADR 0218) sits beside My Chords as its counterpart for progressions the player writes. *Hear* sounds a saved
/// chord from its detail (ADR 0097 Slice 1); the identifier/scales/ear-training sections remain later
/// slices with their own ADRs. The landing is a simple list of sections in the indigo "study/reference"
/// accent (`PocketColor.toolkit`), one visual level down from the home cards.
///
/// The hub is **free forever** (ADR 0144 D2) and gate-free by construction — nothing here reads
/// `isPro`. Help living inside it is deliberate: an undecided or lapsed player can still read what the
/// app does and reach us.
struct ToolkitView: View {
    /// Drives the "N saved" count on the My Chords row — the same `@Query` the library screen reads.
    @Query private var savedChords: [SavedChord]
    /// The same count for My Progressions (ADR 0218).
    @Query private var savedProgressions: [SavedProgression]
    /// And for My tabs (ADR 0235).
    @Query private var writtenTabs: [WrittenTab]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // One list, `ToolkitSection`, which the Home tile beside Toolkit offers too (ADR 0235 D6).
                ForEach(ToolkitSection.allCases) { section in
                    NavigationLink { ToolkitDestination(section: section) } label: {
                        ToolkitSectionRow(icon: section.info.icon,
                                          title: section.info.title,
                                          subtitle: section.info.subtitle,
                                          trailing: trailing(for: section))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(spokenLabel(for: section))
                }
            }
            .padding(20)
            // Cap to a readable column at regular width (iPad / landscape); no-op at compact
            // width, dormant on the iPhone-only v1 build (ADR 0105).
            .readableWidth()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Toolkit")
        .navigationBarTitleDisplayMode(.inline)
        .tint(PocketColor.toolkit)
    }

    /// What sits at a row's end: how many the player has made, or the tool's own state.
    private func trailing(for section: ToolkitSection) -> String {
        switch section {
        case .myChords: savedCountLabel(savedChords.count)
        case .myProgressions: savedCountLabel(savedProgressions.count)
        case .myTabs: savedCountLabel(writtenTabs.count)
        case .tuner: "Free"
        case .glossary: "\(GlossaryTerm.all.count)"
        case .help: "\(FAQEntry.all.count)"
        }
    }

    /// The three things you make say their count; the tools say what they are.
    private func spokenLabel(for section: ToolkitSection) -> String {
        switch section {
        case .myChords, .myProgressions, .myTabs: "\(section.info.title), \(trailing(for: section))"
        case .tuner, .glossary, .help: section.info.spoken
        }
    }

    /// "12 saved" / "1 saved" / "None yet" — a count-aware trailing state.
    private func savedCountLabel(_ count: Int) -> String {
        count == 0 ? "None yet" : "\(count) saved"
    }
}

/// One section row on the Toolkit landing — icon + name + one-line purpose + a count/state, in the
/// indigo accent. The hub's own presentational card, a level down from the home cards.
struct ToolkitSectionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let trailing: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.futura(.title3))
                .foregroundStyle(PocketColor.toolkit)
                .frame(width: 40, height: 40)
                .background(Circle().fill(PocketColor.toolkitCircleWash))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.futura(.headline))
                    .foregroundStyle(PocketColor.textPrimary)
                Text(subtitle)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Spacer(minLength: 8)
            Text(trailing)
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            Image(systemName: "chevron.right")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.toolkitCardWash))
        .accessibilityElement(children: .ignore)
    }
}

// Regular-width variant (ADR 0105): caps to a centred column at iPad / landscape width.
#Preview("Toolkit — regular width (iPad groundwork)") {
    NavigationStack { ToolkitView() }
        .environment(\.horizontalSizeClass, .regular)
        .frame(width: 1024, height: 900)
}

#Preview("Toolkit") {
    NavigationStack { ToolkitView() }
        .modelContainer(for: [SavedChord.self, SavedProgression.self, WrittenTab.self], inMemory: true)
        .preferredColorScheme(.dark)
}
