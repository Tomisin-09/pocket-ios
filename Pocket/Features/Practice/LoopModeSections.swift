import SwiftData
import SwiftUI

// The `Form` sections shared by the loop's two **ramp-less** modes — ear training (ADR 0104) and
// improvising over a backing track (ADR 0135). Both are the same shape: *this is your material*, a
// play control with one live tempo, and a note that lands in the loop's Journal. What differs is the
// copy and the `EntryKind` the note is tagged with, so those are parameters and nothing else is.
//
// Extracted when the second mode arrived rather than copied, because the alternative is two
// identity headers and two tempo adjusters that drift apart one small fix at a time — and the
// tempo adjuster in particular is the control whose bounds have to keep matching
// `ContinuousLoopPlayer`'s.

/// **This is your material** — the loop's name, the song it came from, and a quiet meta line. Always
/// shown: neither mode is an abstract exercise, and knowing which passage is sounding is the point.
struct LoopModeIdentityHeader: View {
    let loop: Loop

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(loop.name.isEmpty ? "Untitled loop" : loop.name)
                .font(.futura(.title2)).bold()
                .foregroundStyle(PocketColor.textPrimary)
            if let song = songLine {
                Text(song)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            if let meta = metaLine {
                Text(meta)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    /// "from {song} · {artist}" — the song this loop was captured from, shown prominently.
    private var songLine: String? {
        guard let song = loop.song else { return nil }
        let artist = song.artist.isEmpty ? "" : " · \(song.artist)"
        return "from \(song.title)\(artist)"
    }

    /// The secondary detail (type · command tempo · time range) as one caption — present but quiet.
    /// An unmeasured loop simply omits the tempo rather than rendering a zero, since neither mode
    /// requires one (ADR 0138 / 0135 B2).
    private var metaLine: String? {
        var parts: [String] = []
        if loop.loopType != .unset { parts.append(loop.loopType.label) }
        if let tempo = loop.commandTempo { parts.append(LoopProgressFormat.percentLabel(tempo)) }
        parts.append("\(timecode(loop.startSeconds))–\(timecode(loop.endSeconds))")
        return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
    }
}

/// The **play control** for a continuously-cycling loop: a big toggle, a state line that is never a
/// score, and the −/+ percent-of-original adjuster that takes effect live while sounding.
struct ContinuousLoopControls: View {
    let player: ContinuousLoopPlayer
    /// What the state line says while audio is cycling — the one line that differs between modes
    /// ("hum or sing along" vs "play over it"). Everything else is the same control.
    let playingStatus: String
    /// What it says before the first tap.
    var idleStatus = "Tap to loop the audio"

    var body: some View {
        VStack(spacing: 12) {
            playButton
            Text(statusLine)
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
            tempoControl
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
    }

    private var playButton: some View {
        Button {
            haptic(.light)
            player.toggle()
        } label: {
            ZStack {
                Circle()
                    .fill(player.isPlaying ? PocketColor.practice : PocketColor.practiceCTA)
                    .frame(width: 108, height: 108)
                if player.isLoading {
                    ProgressView().tint(PocketColor.background)
                } else {
                    Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(PocketColor.background)
                        .offset(x: player.isPlaying ? 0 : 3)   // optical-centre the play triangle
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(player.isUnavailable)
        .accessibilityLabel(player.isPlaying ? "Stop the loop" : "Play the loop")
    }

    /// The state line under the button — never a score, just what the audio is doing.
    private var statusLine: String {
        if player.isUnavailable { return "Audio unavailable — the song file moved or was deleted." }
        if player.isLoading { return "Loading…" }
        return player.isPlaying ? playingStatus : idleStatus
    }

    /// −/+ tempo adjuster (ADR 0104 / 0135 B3): slow the audio down, or nudge it back up. Takes
    /// effect live while sounding. Percent-of-original, matching the loop's tempo vocabulary.
    private var tempoControl: some View {
        HStack(spacing: 20) {
            tempoButton(symbol: "minus.circle.fill", delta: -ContinuousLoopPlayer.step,
                        enabled: player.canSlowDown, label: "Slow down")
            VStack(spacing: 0) {
                Text("\(player.percent)%")
                    .font(.pocketMono(.title3))
                    .foregroundStyle(PocketColor.textPrimary)
                    .monospacedDigit()
                Text("tempo")
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .frame(minWidth: 72)
            tempoButton(symbol: "plus.circle.fill", delta: ContinuousLoopPlayer.step,
                        enabled: player.canSpeedUp, label: "Speed up")
        }
        .disabled(player.isUnavailable)
    }

    private func tempoButton(symbol: String, delta: Int, enabled: Bool, label: String) -> some View {
        Button {
            haptic(.light)
            player.adjustTempo(by: delta)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 32))
                .foregroundStyle(enabled ? PocketColor.practice : PocketColor.surfaceBorder)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

/// **Note capture** straight into the loop's Journal (ADR 0058 / 0100), tagged with the mode's own
/// `EntryKind` — 👂 for ear training, 🎸 for a jam. Owns its own draft and per-session tally, so a
/// host is a `Section` and nothing more.
///
/// The tally drives a quiet "saved" confirmation and is deliberately **not** a count of anything the
/// player did well (ADR 0070 / 0135 B5): it's a receipt that the write landed.
struct LoopModeNoteSection: View {
    let loop: Loop
    let kind: EntryKind
    let header: String
    let placeholder: String

    @Environment(\.modelContext) private var modelContext
    @State private var draftNote = ""
    @State private var savedThisSession = 0
    @FocusState private var noteFocused: Bool

    private var canAdd: Bool {
        !draftNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Section {
            TextField(placeholder, text: $draftNote, axis: .vertical)
                .lineLimit(2...5)
                .keyboardDoneButton()
                // Needs a `KeyboardFollowingScroll` around the host's container — both hosts
                // (`ImproviseSheet`, `EarTrainingSheet`) have one; inert if a third forgets.
                .scrollsIntoViewWhenFocused("mode-note", focused: $noteFocused)

            Button {
                addNote()
            } label: {
                Text("Save to Journal")
                    .font(.futura(.headline))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(canAdd ? PocketColor.background : PocketColor.textSecondary)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(canAdd ? PocketColor.journal : PocketColor.surfaceBorder))
            }
            // `.borderless` so the button is its own hit-target inside the Form row (matches
            // JournalSheet's composer — the default row-wide button swallows the first tap).
            .buttonStyle(.borderless)
            .disabled(!canAdd)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        } header: {
            Text(header)
        } footer: {
            Text(savedThisSession == 0
                 ? "Optional — saves to this loop's Journal tagged \(kind.emoji), on the same "
                    + "timeline as your practice notes."
                 : "Saved to Journal \(kind.emoji) · \(savedThisSession) this session")
        }
    }

    /// Write the note through the shared Journal path (ADR 0058), snapshotting the loop's context
    /// like any loop note. Trims/ignores empty (JournalWriter enforces it too).
    private func addNote() {
        guard JournalWriter.add(to: .loop(loop), text: draftNote, kind: kind, into: modelContext)
        else { return }
        try? modelContext.save()
        haptic(.light)
        draftNote = ""
        savedThisSession += 1
    }
}
