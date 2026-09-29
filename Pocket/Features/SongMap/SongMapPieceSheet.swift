import SwiftUI

/// A loop's **tab**, opened by tapping it on the song map (ADR 0232 D2): what the loop holds, drawn from
/// its piece every time, and the ways to work on it. Reading is the light action, so it's the tap; working
/// on it is one more.
///
/// The tab is `TabLine`'s, the same one *Saved on this loop* and the Journal's Pieces rows draw, so the
/// three can't disagree (**edit pieces, never the picture**, 0225 D10). A name given by ear has no fret,
/// so it lives in the piece's line rather than the tab.
struct SongMapPieceSheet: View {
    let loop: Loop
    let piece: SongMap.Piece
    /// Where it sits: *Notes · Bars 9–11*, or its times in seconds scale.
    let place: String
    /// Open the loop in one of its modes. The map closes this sheet first.
    let onOpen: (LoopRunMode) -> Void
    /// *Repeats through Chorus, 6 times in all.* (ADR 0232 D14, D15), or `nil` when it doesn't repeat.
    var repeatLine: String?
    /// *Copy to…* (D16), or `nil` for a loop with nothing counted to copy. The map closes this sheet first.
    var onCopy: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    private var modes: [LoopRunMode] { SongMapPieceSheet.modes(for: loop) }
    private var spelling: NoteSpelling { CountTheNotesModel.spelling(for: loop) }

    /// The modes this loop can open in, ear training first: it's where a piece is counted and named.
    static func modes(for loop: Loop) -> [LoopRunMode] {
        [LoopRunMode.ear, .trainer, .improvise].filter { LoopModeAccess.allows($0, loop) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(place)
                        .font(.futura(.subheadline))
                        .foregroundStyle(SongMapStyle.tint(piece.layer))
                    content
                    if let repeatLine {
                        Label(repeatLine, systemImage: "repeat")
                            .font(.futura(.footnote))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                }
                actions
            }
            .navigationTitle(piece.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - What it holds

    @ViewBuilder private var content: some View {
        switch piece.content {
        case .empty:
            hint("Not counted yet. Count it in Train your ear, then name the notes to see its tab here.")
        case .handTagged:
            Text("\(EntryKind.transcribed.emoji) Tagged Transcribed in a note.")
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textPrimary)
            hint("Count it in Train your ear to see it here.")
        case .piece(let transcription):
            if let line = transcription.summary(spelling: spelling) {
                Text(line)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
            }
            if let tab = TabLine.render(transcription.labels, openMidi: transcription.openMidi ?? []) {
                VStack(alignment: .leading, spacing: 4) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(tab)
                            .font(.pocketMono(.footnote))
                            .foregroundStyle(PocketColor.textPrimary)
                            .fixedSize()
                            .textSelection(.enabled)
                    }
                    if let tuning = transcription.tuningLabel {
                        Text(tuning)
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                }
            } else if piece.layer == .notes {
                hint("Name the notes on the neck in Train your ear and their tab appears here.")
            }
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.futura(.footnote))
            .foregroundStyle(PocketColor.textSecondary)
    }

    // MARK: - Ways in

    @ViewBuilder private var actions: some View {
        Section {
            ForEach(modes) { mode in
                Button { onOpen(mode) } label: {
                    Label(mode.label, systemImage: mode.symbolName)
                        .foregroundStyle(PocketColor.practice)
                }
            }
            if let onCopy {
                Button(action: onCopy) {
                    Label("Copy to…", systemImage: "square.on.square")
                        .foregroundStyle(PocketColor.practice)
                }
            }
        } footer: {
            if modes.isEmpty {
                Text("This song's audio can't play here, so the loop can't open.")
            }
        }
    }
}
