import SwiftUI

/// A pickable unit row in the add-to-routine picker with an optional **audio audition** (ADR 0104
/// Slice 2 follow-up). Loops in a routine are often named indistinctly ("Loop 5", "Loop 8"), so a
/// loop/ear row carries a speaker button that plays the loop's real audio in place — the same
/// `LoopAudioPreviewPlayer` used elsewhere, auto-stopping after a few seconds.
///
/// **One at a time:** the parent owns a `playingID` binding; starting a preview claims it, and any
/// other row observing a different id stops its own player. The main body taps to pick; the speaker is
/// an independent `.borderless` hit-target (the pattern for a second control inside a List row —
/// `JournalSheet`'s composer is the precedent). Rows with no `previewLoop` (exercises/songs) render
/// just the pick button.
struct AddRoutineUnitRow: View {
    let row: PickRow
    @Binding var playingID: String?
    @State private var player: LoopAudioPreviewPlayer?

    var body: some View {
        HStack(spacing: 8) {
            Button { row.pick() } label: {
                PracticeUnitRow(title: row.title, context: row.context, progress: row.progress)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let loop = row.previewLoop {
                previewButton(loop)
            }
        }
        // Another row claimed playback — silence this one so only one loop ever sounds.
        .onChange(of: playingID) { _, newValue in
            if newValue != row.id { player?.stop() }
        }
        .onDisappear { player?.stop() }
    }

    private func previewButton(_ loop: Loop) -> some View {
        let isPlaying = player?.isPlaying ?? false
        return Button {
            haptic(.light)
            if isPlaying {
                player?.stop()
                playingID = nil
            } else {
                // Fresh player per audition so a re-tap after the auto-stop replays cleanly.
                let fresh = LoopAudioPreviewPlayer(loop: loop)
                player = fresh
                playingID = row.id
                fresh.toggle()
            }
        } label: {
            Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle")
                .font(.futura(.title3))
                .foregroundStyle(player?.isUnavailable == true
                                 ? PocketColor.textSecondary.opacity(0.4) : PocketColor.practice)
        }
        .buttonStyle(.borderless)
        .disabled(player?.isUnavailable == true)
        .accessibilityLabel(isPlaying ? "Stop preview" : "Preview loop audio")
    }
}
