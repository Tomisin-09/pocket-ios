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
    // All songs, to suggest collections already used across the library (ADR 0033).
    @Query private var allSongs: [Song]

    @State private var title: String
    @State private var artist: String
    @State private var album: String
    @State private var genre: String
    @State private var year: String          // numeric text → Int? on save
    @State private var key: MusicalKey        // closed picker → Song.musicalKey on save (ADR 0036)
    @State private var bpm: String           // numeric text → Int? on save
    @State private var downbeat: String      // decimal seconds → TimeInterval? on save (ADR 0022)
    @State private var collections: [String]
    @State private var comment: String
    @State private var newCollection = ""

    init(song: Song) {
        self.song = song
        _title = State(initialValue: song.title)
        _artist = State(initialValue: song.artist)
        _album = State(initialValue: song.album)
        _genre = State(initialValue: song.genre)
        _year = State(initialValue: song.year.map(String.init) ?? "")
        _key = State(initialValue: song.musicalKey)
        _bpm = State(initialValue: song.bpm.map(String.init) ?? "")
        _downbeat = State(initialValue: song.downbeatSeconds.map { String(format: "%g", $0) } ?? "")
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
            ClearableTextField("Genre", text: $genre)
            NumberRow(label: "Year", text: $year)
            Picker("Key", selection: $key) {
                ForEach(MusicalKey.pickerOrder) { key in
                    Text(key.pickerLabel).tag(key)
                }
            }
            .foregroundStyle(PocketColor.textSecondary)
            NumberRow(label: "BPM", text: $bpm)
            // Downbeat phase anchor for the beat grid (ADR 0022) — the seconds at
            // which bar 1 lands. Decimal seconds; empty ⇒ no grid. Needs BPM to do
            // anything, so it reads as "off" until both are set.
            NumberRow(label: "Downbeat (s)", text: $downbeat, keyboard: .decimalPad)
        }
    }

    private var collectionsSection: some View {
        Section("Collections") {
            ForEach(collections, id: \.self) { collection in
                Text(collection).foregroundStyle(PocketColor.textPrimary)
            }
            .onDelete { collections.remove(atOffsets: $0) }
            HStack {
                TextField("Add a collection", text: $newCollection)
                    .submitLabel(.done)
                    .onSubmit(addCollection)
                Button("Add", action: addCollection)
                    .disabled(Labels.canonical(newCollection) == nil)
            }
            if !collectionSuggestions.isEmpty {
                suggestionChips
            }
        }
    }

    /// Tappable chips of collections already used elsewhere in the library — tap to
    /// add the canonical form (reuse over re-entry, the convergence mechanism).
    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(collectionSuggestions, id: \.self) { suggestion in
                    Button {
                        collections = Labels.adding(suggestion, to: collections)
                    } label: {
                        Text(suggestion)
                            .font(.pocketMono(.caption))
                            .lineLimit(1)
                            .foregroundStyle(PocketColor.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    private var collectionSuggestions: [String] {
        Labels.suggestions(from: allSongs.flatMap(\.collections), excluding: collections)
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

    private func addCollection() {
        // Canonicalise and de-dup case-insensitively through the shared normaliser
        // (ADR 0033) so the collection set doesn't fragment into Blues/blues/"blues ".
        collections = Labels.adding(newCollection, to: collections)
        newCollection = ""
    }

    /// Write the edited values back to the persisted `Song`. Title falls back to the
    /// existing one when cleared (the library sorts and labels rows by it).
    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        song.title = trimmedTitle.isEmpty ? song.title : trimmedTitle
        song.artist = artist
        song.album = album
        song.genre = genre
        song.year = Int(year)
        song.musicalKey = key
        song.bpm = Int(bpm)
        song.downbeatSeconds = Double(downbeat.trimmingCharacters(in: .whitespaces))
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
    var keyboard: UIKeyboardType = .numberPad

    var body: some View {
        HStack {
            Text(label).foregroundStyle(PocketColor.textSecondary)
            Spacer()
            TextField("—", text: $text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .font(.pocketMono(.body))
                .frame(maxWidth: 90)
        }
    }
}
