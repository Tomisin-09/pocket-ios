import SwiftData
import SwiftUI

/// Edit a song's metadata (ADR 0012). Reached by swiping a library row → Edit.
/// Mirrors the loop/marker sheets (`WaveformEditSheets.swift`): local `@State`
/// seeded in `init`, written back to the persisted `Song` on **Done** so **Cancel**
/// discards. Read-only practice stats (loops / markers / annotations) sit at the
/// bottom — the song record is where we enrich the data that drives routines.
struct SongEditSheet: View {
    let song: Song

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var artist: String
    @State private var album: String
    @State private var year: String          // numeric text → Int? on save
    @State private var key: String
    @State private var bpm: String           // numeric text → Int? on save
    @State private var proficiency: Int
    @State private var progression: String
    @State private var collections: [String]
    @State private var comment: String
    @State private var newCollection = ""

    init(song: Song) {
        self.song = song
        _title = State(initialValue: song.title)
        _artist = State(initialValue: song.artist)
        _album = State(initialValue: song.album)
        _year = State(initialValue: song.year.map(String.init) ?? "")
        _key = State(initialValue: song.key)
        _bpm = State(initialValue: song.bpm.map(String.init) ?? "")
        _proficiency = State(initialValue: song.proficiency)
        _progression = State(initialValue: song.progression)
        _collections = State(initialValue: song.collections)
        _comment = State(initialValue: song.comment)
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                collectionsSection
                notesSection
                statsSection
            }
            .navigationTitle("Edit song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save)
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section("Details") {
            ClearableTextField("Title", text: $title)
            ClearableTextField("Artist", text: $artist)
            ClearableTextField("Album", text: $album)
            NumberRow(label: "Year", text: $year)
            ClearableTextField("Key", text: $key)
            NumberRow(label: "BPM", text: $bpm)
            ProficiencyPicker(value: $proficiency)
            ClearableTextField("Progression", text: $progression)
        }
    }

    private var collectionsSection: some View {
        Section("Collections") {
            ForEach(collections, id: \.self) { tag in
                Text(tag).foregroundStyle(PocketColor.textPrimary)
            }
            .onDelete { collections.remove(atOffsets: $0) }
            HStack {
                TextField("Add a collection", text: $newCollection)
                    .submitLabel(.done)
                    .onSubmit(addCollection)
                Button("Add", action: addCollection)
                    .disabled(trimmedNewCollection.isEmpty)
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("A note about this song", text: $comment, axis: .vertical)
                .lineLimit(3...8)
        }
    }

    private var statsSection: some View {
        Section("Practice stats") {
            statRow("Loops", song.loops.count)
            statRow("Markers", song.markers.count)
            statRow("Annotations", song.annotationCount)
        }
    }

    private func statRow(_ label: String, _ value: Int) -> some View {
        LabeledContent(label) {
            Text("\(value)").font(.pocketMono(.body)).foregroundStyle(PocketColor.textPrimary)
        }
    }

    // MARK: - Actions

    private var trimmedNewCollection: String {
        newCollection.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addCollection() {
        let tag = trimmedNewCollection
        newCollection = ""
        guard !tag.isEmpty, !collections.contains(tag) else { return }
        collections.append(tag)
    }

    /// Write the edited values back to the persisted `Song`. Title falls back to the
    /// existing one when cleared (the library sorts and labels rows by it).
    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        song.title = trimmedTitle.isEmpty ? song.title : trimmedTitle
        song.artist = artist
        song.album = album
        song.year = Int(year)
        song.key = key
        song.bpm = Int(bpm)
        song.proficiency = proficiency
        song.progression = progression
        song.collections = collections
        song.comment = comment
        dismiss()
    }
}

/// A right-aligned numeric field for optional integer metadata (Year, BPM). Empty
/// reads as "unknown" (`nil`); a `—` placeholder makes that state legible.
private struct NumberRow: View {
    let label: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(PocketColor.textSecondary)
            Spacer()
            TextField("—", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.pocketMono(.body))
                .frame(maxWidth: 90)
        }
    }
}

/// A 0–5 star proficiency control. Tapping a star sets that level; tapping the
/// current level steps back down one (so 0 is reachable). Amber matches the
/// library row's `ProficiencyDots`.
private struct ProficiencyPicker: View {
    @Binding var value: Int

    var body: some View {
        HStack {
            Text("Proficiency").foregroundStyle(PocketColor.textSecondary)
            Spacer()
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { level in
                    Button {
                        value = (value == level) ? level - 1 : level
                    } label: {
                        Image(systemName: level <= value ? "star.fill" : "star")
                            .foregroundStyle(level <= value ? PocketColor.marker : PocketColor.barDefault)
                    }
                    .buttonStyle(.plain)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Proficiency")
            .accessibilityValue("\(value) of 5")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: value = min(5, value + 1)
                case .decrement: value = max(0, value - 1)
                @unknown default: break
                }
            }
        }
    }
}
