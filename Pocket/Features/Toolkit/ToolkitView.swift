import SwiftData
import SwiftUI

/// The **Toolkit** hub landing (ADR 0096 Slice 1) — the app's free, deterministic *reference*
/// destination, distinct from the exercise editors (which *author* practice content). Reached from the
/// fourth home card; relies on an ambient `NavigationStack` (pushed from Home, like `PracticeView` /
/// `LibraryView`) rather than owning one, so its sections push onto the home stack.
///
/// Slice 1 carries the only two zero-dependency tenants (ADR 0096 D5): **My Chords** (the `SavedChord`
/// library promoted from the in-context menu to a full screen) and a static **Glossary**. It is
/// **audio-free by construction** — *Hear* and the identifier/scales/ear-training sections are Slice 2+
/// with their own ADRs (D4). The landing is a simple list of sections in the indigo "study/reference"
/// accent (`PocketColor.toolkit`), one visual level down from the home cards.
struct ToolkitView: View {
    /// Drives the "N saved" count on the My Chords row — the same `@Query` the library screen reads.
    @Query private var savedChords: [SavedChord]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                NavigationLink { MyChordsView() } label: {
                    ToolkitSectionRow(icon: "square.grid.2x2",
                                      title: "My chords",
                                      subtitle: "Your saved voicings",
                                      trailing: savedCountLabel)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("My chords, \(savedCountLabel)")

                NavigationLink { GlossaryView() } label: {
                    ToolkitSectionRow(icon: "text.book.closed",
                                      title: "Glossary",
                                      subtitle: "Chord, scale & theory terms",
                                      trailing: "\(GlossaryTerm.all.count)")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Glossary, chord, scale and theory terms")

                // SPIKE (ADR 0096 D4): throwaway entry to the Hear tone bench. Remove with
                // HearSpikeView / ChordTonePlayer once the D4 sound-source decision is made.
                NavigationLink { HearSpikeView() } label: {
                    ToolkitSectionRow(icon: "speaker.wave.2",
                                      title: "Hear spike",
                                      subtitle: "D4 tone bench (throwaway)",
                                      trailing: "SPIKE")
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Toolkit")
        .navigationBarTitleDisplayMode(.inline)
        .tint(PocketColor.toolkit)
    }

    /// "12 saved" / "1 saved" / "None yet" — a count-aware trailing state for the My Chords row.
    private var savedCountLabel: String {
        savedChords.isEmpty ? "None yet"
                            : "\(savedChords.count) saved"
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

#Preview("Toolkit") {
    NavigationStack { ToolkitView() }
        .modelContainer(for: SavedChord.self, inMemory: true)
        .preferredColorScheme(.dark)
}
