import SwiftData
import SwiftUI

/// The reusable **ear-training core** for a loop (ADR 0104) — the identity header, the continuous
/// play control, the live tempo adjuster, and Journal note capture. Rendered as a `Form` with no
/// navigation chrome of its own, so it drops into two hosts: the standalone `EarTrainingSheet`
/// (from the loop settings sheet) and `EarLoopRunView` (an ear-training block inside a routine).
///
/// Ear training as "the loops, re-surfaced": an away-from-the-guitar exercise — the loop's own audio
/// cycles continuously so the player can **hum or sing it back** and listen again to compare. No
/// stored answer, no verdict (ADR 0070/0094 T2b): the app plays, nothing listens, the player is the
/// judge. Notes save straight to the loop's **Journal** (ADR 0100/0058) tagged 👂 `.ear`.
struct EarTrainingView: View {
    let loop: Loop

    @Environment(\.modelContext) private var modelContext
    @State private var player: EarTrainingPlayer
    @State private var draftNote = ""
    /// Ear-notes saved this session — drives a quiet "saved to Journal" confirmation, no tally/score.
    @State private var savedThisSession = 0

    init(loop: Loop) {
        self.loop = loop
        _player = State(initialValue: EarTrainingPlayer(loop: loop))
    }

    private var canAdd: Bool {
        !draftNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            identitySection
            introSection
            listenSection
            noteSection
        }
        .onDisappear { player.stop() }
    }

    // MARK: - Identity (always shown — this is your material)

    private var identitySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(loopName)
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
    }

    private var loopName: String { loop.name.isEmpty ? "Untitled loop" : loop.name }

    /// "from {song} · {artist}" — the song this loop was captured from, shown prominently.
    private var songLine: String? {
        guard let song = loop.song else { return nil }
        let artist = song.artist.isEmpty ? "" : " · \(song.artist)"
        return "from \(song.title)\(artist)"
    }

    /// The secondary detail (type · command tempo · time range) as one caption — present but quiet.
    private var metaLine: String? {
        var parts: [String] = []
        if loop.loopType != .unset { parts.append(loop.loopType.label) }
        if let tempo = loop.commandTempo { parts.append(LoopProgressFormat.percentLabel(tempo)) }
        parts.append("\(timecode(loop.startSeconds))–\(timecode(loop.endSeconds))")
        return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
    }

    // MARK: - Intro (hum / sing, away from the guitar)

    private var introSection: some View {
        Section {
            Text("Listen it into your ear, then hum or sing it back — no guitar needed. Play the loop "
                + "again and compare. No score, no right answer. Jot what you hear below.")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    // MARK: - Listen + tempo

    private var listenSection: some View {
        Section {
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
        return player.isPlaying ? "Looping — hum or sing along" : "Tap to loop the audio"
    }

    /// −/+ tempo adjuster (ADR 0104): slow the audio down to internalise, or nudge it back up. Takes
    /// effect live while sounding. Percent-of-original, matching the loop's tempo vocabulary.
    private var tempoControl: some View {
        HStack(spacing: 20) {
            tempoButton(symbol: "minus.circle.fill", delta: -EarTrainingPlayer.step,
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
            tempoButton(symbol: "plus.circle.fill", delta: EarTrainingPlayer.step,
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

    // MARK: - Note what you hear → Journal (tagged 👂)

    private var noteSection: some View {
        Section {
            TextField("What did you hear? (e.g. starts on the b3, descending run)",
                      text: $draftNote, axis: .vertical)
                .lineLimit(2...5)
                .keyboardDoneButton()

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
            Text("Note what you hear")
        } footer: {
            Text(savedThisSession == 0
                 ? "Optional — saves to this loop's Journal tagged 👂, on the same timeline as your "
                    + "practice notes."
                 : "Saved to Journal 👂 · \(savedThisSession) this session")
        }
    }

    /// Write the ear-note through the shared Journal path (ADR 0058), tagged `.ear`, snapshotting the
    /// loop's context like any loop note. Trims/ignores empty (JournalWriter enforces it too).
    private func addNote() {
        guard JournalWriter.add(to: .loop(loop), text: draftNote, kind: .ear, into: modelContext)
        else { return }
        try? modelContext.save()
        haptic(.light)
        draftNote = ""
        savedThisSession += 1
    }
}

/// The **standalone** ear-training host — presented from the loop settings sheet (ADR 0104). Wraps
/// `EarTrainingView` in a navigation container with a Done button; the routine block uses
/// `EarLoopRunView` instead.
struct EarTrainingSheet: View {
    let loop: Loop
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            EarTrainingView(loop: loop)
                .navigationTitle("Train your ear")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.large])
    }
}

#Preview("Train your ear") {
    let song = Song.sample()
    let loop = Loop(name: "Verse riff", start: 0.2, end: 0.35, speed: 0.85, repeats: 4)
    loop.song = song
    loop.loopType = .lick
    loop.commandTempo = 0.85
    loop.tags = ["solo", "bends"]
    return EarTrainingSheet(loop: loop).preferredColorScheme(.dark)
}
