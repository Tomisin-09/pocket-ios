import SwiftUI

/// The first-song walkthrough's card (ADR 0149, ADR 0220 D3): the three beats, the experienced
/// player's offer, and the one ceremony — whichever `SongWalkthrough.phase` says. On the starter
/// track it also carries the session's two hints (D4), under the beats and set apart from them, and
/// once the beats are done a hint can be all it shows.
///
/// **It instructs; it never advances.** There is no Next anywhere on it (0149 §1): a beat ticks when
/// the model reports the player did the thing. The only buttons are the ✕ (permanent, §4), the
/// offer's yes, and each beat's single link into Help & FAQs (§6), which opens the answer rather than
/// explaining itself here.
///
/// Placed by the layout: pinned above the reference list in portrait, directly under the transport
/// whose Loop button beat 1 is about, and inline in the cockpit in landscape, where that list is a
/// closed drawer. `compact` (landscape) shows only the current beat.
///
/// Reads `model.starterScript`, never the playhead: the script is written only when its stage moves,
/// so this body re-runs a handful of times a walkthrough, not at display rate (ADR 0153).
struct WalkthroughCard: View {
    let model: WaveformPracticeModel
    var compact = false
    @State private var helpEntry: FAQEntry?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let walkthrough = model.walkthrough {
                content(for: walkthrough)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.walkthrough)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.starterScript)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.walkthroughHint)
        .sheet(item: $helpEntry) { FAQAnswerSheet(entry: $0) }
        // The pause is silent on screen apart from the ring, so a VoiceOver player is *told* when
        // the script is waiting on them rather than having to find what changed.
        .onChange(of: model.starterScript?.stage) { _, stage in
            guard model.walkthroughHintsLoop, let text = stage?.instruction(isPlaying: false) else { return }
            AccessibilityNotification.Announcement(text).post()
        }
        // A hint is a ring and a line, both easy to miss without sight of the screen (D4).
        .onChange(of: model.walkthroughHint) { _, hint in
            guard let hint else { return }
            AccessibilityNotification.Announcement(hintBody(hint)).post()
        }
    }

    @ViewBuilder
    private func content(for walkthrough: SongWalkthrough) -> some View {
        switch walkthrough.phase {
        case .offered: offer
        case .running(let beat): beats(walkthrough, current: beat)
        case .ceremony: ceremony
        case .finished:
            // The beats are done; what can remain is the backing-track hint, which arrives after the
            // ceremony (D4). Its ✕ is the card's: closing the last thing on it ends the walkthrough.
            if let hint = model.walkthroughHint {
                hintRow(hint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(WalkthroughCardChrome(onClose: model.dismissWalkthroughHint,
                                                    closeLabel: hint.dismissLabel))
            }
        }
    }

    // MARK: The offer (0149 §4)

    private var offer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(SongWalkthrough.offerTitle)
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
            Text(SongWalkthrough.offerBody)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Button("Show me", action: model.acceptWalkthrough)
                    .font(.futura(.subheadline, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(PocketColor.practiceCTA)
                Button("Not now", action: model.dismissWalkthrough)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(WalkthroughCardChrome())
    }

    // MARK: The beats (0149 amendment)

    private func beats(_ walkthrough: SongWalkthrough, current: SongWalkthrough.Beat) -> some View {
        VStack(alignment: .leading, spacing: compact ? 0 : 10) {
            ForEach(compact ? [current] : SongWalkthrough.Beat.allCases) { beat in
                if beat == current {
                    currentRow(beat)
                } else {
                    otherRow(beat, done: walkthrough.completed.contains(beat))
                }
            }
            if let hint = model.walkthroughHint {
                Divider().padding(.vertical, compact ? 6 : 2)
                hintRow(hint)
                    .overlay(alignment: .topTrailing) { hintClose(hint) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(WalkthroughCardChrome(onClose: model.dismissWalkthrough))
    }

    private func currentRow(_ beat: SongWalkthrough.Beat) -> some View {
        HStack(alignment: .top, spacing: 10) {
            BeatBadge(beat: beat, state: .current)
            VStack(alignment: .leading, spacing: 4) {
                Text(beat.title)
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                Text(instruction(for: beat))
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let entry = beat.helpEntry {
                    Button {
                        helpEntry = entry
                    } label: {
                        Text(beat.helpLinkTitle + " ›")
                            .font(.futura(.footnote, weight: .medium))
                            .foregroundStyle(PocketColor.practice)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            // Room for the card's ✕, which sits in this corner.
            Spacer(minLength: 28)
        }
    }

    private func otherRow(_ beat: SongWalkthrough.Beat, done: Bool) -> some View {
        HStack(spacing: 10) {
            BeatBadge(beat: beat, state: done ? .done : .upcoming)
            Text(beat.title)
                .font(.futura(.subheadline))
                .foregroundStyle(done ? PocketColor.textSecondary : PocketColor.textSecondary.opacity(0.6))
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? "Done" : "Not yet")
    }

    /// Beat 1 on the starter track follows the script (ADR 0220 D3); every other beat, and beat 1 on
    /// any other song (D6), reads the same words every time.
    private func instruction(for beat: SongWalkthrough.Beat) -> String {
        if beat == .loopIt,
           let scripted = model.starterScript?.stage.instruction(isPlaying: model.engine.isPlaying) {
            return scripted
        }
        return beat.instruction
    }

    // MARK: The hints (ADR 0220 D4)

    /// A hint, set apart from the beats: its badge is the glyph of what it points at rather than a
    /// number, because it is not a step. The ring on the control does the pointing.
    private func hintRow(_ hint: StarterTrackHints.Hint) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(PocketColor.surfaceStandard.opacity(0.6))
                Image(systemName: hint == .click ? "metronome" : "repeat")
                    .font(.futura(size: 10, weight: .semibold))
                    .foregroundStyle(PocketColor.waveformAccent)
            }
            .frame(width: 20, height: 20)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                // In the accent, not the current beat's white: two bold white titles on one card
                // read as two steps, and a hint is not one (seen on the simulator).
                Text(hint.title)
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.waveformAccent)
                Text(hintBody(hint))
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 28)
        }
        .accessibilityElement(children: .combine)
    }

    /// The hint's own ✕ while beats are still on the card — the card's ✕ above it ends the guide.
    private func hintClose(_ hint: StarterTrackHints.Hint) -> some View {
        Button(action: model.dismissWalkthroughHint) {
            Image(systemName: "xmark")
                .font(.futura(size: 11, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: 10, y: -6)
        .accessibilityLabel(hint.dismissLabel)
    }

    private func hintBody(_ hint: StarterTrackHints.Hint) -> String {
        hint.body(loopName: model.walkthroughHintedLoopName)
    }

    // MARK: The ceremony (0149 §5)

    private var ceremony: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "moon.fill")
                .font(.futura(size: 18, weight: .semibold))
                .foregroundStyle(PocketColor.library)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(SongWalkthrough.ceremonyTitle)
                    .font(.futura(.headline))
                    .foregroundStyle(PocketColor.textPrimary)
                Text(SongWalkthrough.ceremonyBody(songTitle: model.song.title))
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .modifier(WalkthroughCardChrome(wash: PocketColor.practiceCardWash,
                                        onClose: model.dismissWalkthroughCeremony))
    }
}

/// A beat's number, or its tick.
private struct BeatBadge: View {
    enum State { case done, current, upcoming }
    let beat: SongWalkthrough.Beat
    let state: State

    private var number: Int { (SongWalkthrough.Beat.allCases.firstIndex(of: beat) ?? 0) + 1 }

    var body: some View {
        ZStack {
            Circle().fill(fill)
            if state == .done {
                Image(systemName: "checkmark")
                    .font(.futura(size: 10, weight: .bold))
            } else {
                Text("\(number)")
                    .font(.futura(size: 11, weight: .semibold))
            }
        }
        .foregroundStyle(ink)
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }

    private var fill: Color {
        switch state {
        case .done: return PocketColor.practice
        case .current: return PocketColor.practiceCircleWash
        case .upcoming: return PocketColor.surfaceStandard
        }
    }

    private var ink: Color {
        switch state {
        case .done: return PocketColor.background
        case .current: return PocketColor.practice
        case .upcoming: return PocketColor.textSecondary
        }
    }
}

/// The card's surface, and the ✕ that ends the walkthrough for good.
private struct WalkthroughCardChrome: ViewModifier {
    var wash: Color = PocketColor.surfaceStandard
    var onClose: (() -> Void)?
    var closeLabel = "Close the guide"

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(wash))
            .overlay(alignment: .topTrailing) {
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.futura(size: 12, weight: .semibold))
                            .foregroundStyle(PocketColor.textSecondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    .accessibilityLabel(closeLabel)
                }
            }
    }
}

/// One Help & FAQs answer, opened from a beat's link (0149 §6). The catalog stays the one place the
/// words live: this shows an `FAQEntry` exactly as the Help screen does, and adds nothing to it.
struct FAQAnswerSheet: View {
    let entry: FAQEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(entry.question)
                        .font(.futura(.title3, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(entry.answer)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textSecondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
