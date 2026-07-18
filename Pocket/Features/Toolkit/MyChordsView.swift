import SwiftData
import SwiftUI

/// **My Chords** (ADR 0096 Slice 1) — the `SavedChord` library (ADR 0095) *promoted* from the chord
/// editor's in-context Add menu to a full screen inside the Toolkit hub. A grid of the player's saved
/// voicings, newest first; tap a chord for its large diagram + rename/delete; **+** builds a new one via
/// the existing `CustomChordSheet` placer in "Save" mode (ADR 0096 — confirming keeps it here rather
/// than inserting into a progression).
///
/// The in-context menu section (`SavedChordsSheet`, ADR 0095) **stays** — that is where the library is
/// *reused inline* in an exercise; this screen is where it is *managed*. Both read the same `@Query`.
/// *Hear* (block-chord tone preview, ADR 0097 Slice 1) lives on the chord detail; the identifier
/// reading is a later Toolkit slice (ADR 0096 D4).
struct MyChordsView: View {
    @Environment(\.modelContext) private var modelContext

    /// Newest first — the just-built chord lands at the top where the player looks for it.
    @Query(sort: \SavedChord.createdAt, order: .reverse) private var savedChords: [SavedChord]

    @State private var building = false

    /// Two columns of diagrams read as a library without crowding the four-fret boxes.
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        Group {
            if savedChords.isEmpty { emptyState } else { grid }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("My chords")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { building = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Build a chord")
            }
        }
        .fullScreenCover(isPresented: $building) {
            // Reuse the placer in "Save" mode: confirming keeps the shape in My Chords instead of
            // inserting it into a progression. The identifier panel still suggests names as the shape forms.
            CustomChordSheet(onInsert: save, confirmTitle: "Save")
        }
        .tint(PocketColor.toolkit)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(savedChords) { saved in
                    NavigationLink {
                        MyChordDetailView(chord: saved)
                    } label: {
                        ChordDiagramView(voicing: saved.voicing, tint: PocketColor.toolkit)
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 16)
                                .fill(PocketColor.toolkitCardWash))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Chord \(saved.name)")
                }
            }
            .padding(20)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No saved chords yet", systemImage: "square.grid.2x2")
        } description: {
            Text("Chords you save turn up here. Build one, or save one from any chord exercise.")
        } actions: {
            Button { building = true } label: {
                Label("Build a chord", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(PocketColor.toolkit)
        }
    }

    /// Persist an authored voicing, skipping an exact duplicate (same name + geometry) so building the
    /// same shape twice doesn't stack identical entries — the ADR 0095 dedupe rule the editor uses.
    private func save(_ voicing: ChordVoicing) {
        guard !SavedChord.isAlreadySaved(voicing, among: savedChords.map(\.voicing)) else { return }
        modelContext.insert(SavedChord(voicing))
    }
}

/// A saved chord's detail — its large diagram, a *Hear* preview, plus manage actions (rename, delete).
/// Reached by tapping a cell in `MyChordsView`. Deleting pops back to the grid. *Hear* sounds the
/// voicing as a block chord through the shared `ToneEngine` (ADR 0097 Slice 1); *Use in an exercise* /
/// the identifier reading are deferred to later Toolkit slices (ADR 0096 §3.1).
struct MyChordDetailView: View {
    @Bindable var chord: SavedChord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var renaming = false
    @State private var draftName = ""
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Width-sized (not `.scaleEffect`, which keeps the old layout bounds and overflowed onto
                // the buttons below); the box lays out to its intrinsic 0.82 aspect. Name suppressed — the
                // navigation title already names the chord.
                ChordDiagramView(voicing: chord.voicing, tint: PocketColor.toolkit, showsName: false)
                    .frame(width: 240)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                VStack(spacing: 12) {
                    Button {
                        ToneEngine.shared.sound(chord.voicing.midiNotes)
                    } label: {
                        Label("Hear", systemImage: "speaker.wave.2.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PocketColor.toolkit)

                    Button {
                        draftName = chord.name
                        renaming = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(PocketColor.toolkit)

                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(PocketColor.danger)
                }
                .font(.futura(.subheadline, weight: .semibold))
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(chord.name)
        .navigationBarTitleDisplayMode(.inline)
        .tint(PocketColor.toolkit)
        .onDisappear { ToneEngine.shared.stop() }
        .alert("Rename chord", isPresented: $renaming) {
            TextField("Name", text: $draftName)
                .autocorrectionDisabled()
            Button("Save") { chord.rename(to: draftName) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this chord?", isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(chord)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(chord.name)” will be removed from My chords. This can't be undone.")
        }
    }
}

#Preview("My chords — populated") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: SavedChord.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    for name in ["Cadd9", "F♯7♯9", "Dsus4"] {
        container.mainContext.insert(SavedChord(ChordVoicing(name, frets: [3, 3, 2, 0, 1, 0])))
    }
    return NavigationStack { MyChordsView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}

#Preview("My chords — empty") {
    NavigationStack { MyChordsView() }
        .modelContainer(for: SavedChord.self, inMemory: true)
        .preferredColorScheme(.dark)
}
