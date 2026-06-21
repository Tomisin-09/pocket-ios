import SwiftUI

/// A read-first **song details** view, opened by holding the title on the practice
/// screen (workstream 5). It reads as a descriptive overview — title/artist header,
/// the song's musical facts, collections, notes, and practice stats — rather than a
/// form of editable fields. Editing is one tap away via **Edit**, which presents the
/// existing `SongEditSheet`; on save the values flow back through the observed `Song`.
struct SongDetailsSheet: View {
    let song: Song

    @Environment(\.dismiss) private var dismiss
    @State private var editing = false

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                detailsSection
                if !song.collections.isEmpty { collectionsSection }
                if !song.comment.isEmpty { notesSection }
                statsSection
            }
            .navigationTitle("Song details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit") { editing = true }
                }
            }
        }
        .presentationDetents([.large])
        // Edit is a nested sheet over the details so dismissing it returns here; the
        // edited values write straight back to the persisted `Song`, which this view
        // observes, so the read view refreshes on save.
        .sheet(isPresented: $editing) {
            SongEditSheet(song: song)
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                if !song.artist.isEmpty {
                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundStyle(PocketColor.textSecondary)
                }
                if !albumLine.isEmpty {
                    Text(albumLine)
                        .font(.footnote)
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }

    private var detailsSection: some View {
        Section {
            detailRow("Key", song.key.isEmpty ? "—" : song.key)
            DetailLabeledContent(label: "Tempo") {
                Text(tempoText).font(.pocketMono(.body)).foregroundStyle(PocketColor.textPrimary)
            }
            DetailLabeledContent(label: "Proficiency") {
                Text(stars(song.proficiency)).foregroundStyle(PocketColor.marker)
            }
            detailRow("Progression", song.progression.isEmpty ? "—" : song.progression)
            DetailLabeledContent(label: "Length") {
                Text(timecode(song.duration)).font(.pocketMono(.body)).foregroundStyle(PocketColor.textPrimary)
            }
        }
    }

    private var collectionsSection: some View {
        Section("Collections") {
            ForEach(song.collections, id: \.self) { tag in
                Text(tag).foregroundStyle(PocketColor.textPrimary)
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            Text(song.comment).foregroundStyle(PocketColor.textPrimary)
        }
    }

    private var statsSection: some View {
        Section("Practice stats") {
            statRow("Loops", song.loops.count)
            statRow("Markers", song.markers.count)
            statRow("Annotations", song.annotationCount)
        }
    }

    // MARK: - Row builders

    private func detailRow(_ label: String, _ value: String) -> some View {
        DetailLabeledContent(label: label) {
            Text(value).foregroundStyle(PocketColor.textPrimary)
        }
    }

    private func statRow(_ label: String, _ value: Int) -> some View {
        DetailLabeledContent(label: label) {
            Text("\(value)").font(.pocketMono(.body)).foregroundStyle(PocketColor.textPrimary)
        }
    }

    // MARK: - Derived text

    /// `Album · Year`, omitting whichever half is unknown (empty when neither is set).
    private var albumLine: String {
        [song.album.isEmpty ? nil : song.album, song.year.map(String.init)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var tempoText: String {
        song.bpm.map { "\($0) BPM" } ?? "—"
    }
}

/// A details row: a secondary label on the left, the supplied value view trailing.
/// Mirrors the edit sheet's row rhythm so details and edit feel like one place.
private struct DetailLabeledContent<Value: View>: View {
    let label: String
    @ViewBuilder let value: () -> Value

    var body: some View {
        LabeledContent {
            value()
        } label: {
            Text(label).foregroundStyle(PocketColor.textSecondary)
        }
    }
}
