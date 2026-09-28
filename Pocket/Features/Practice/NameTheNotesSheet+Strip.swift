import SwiftUI

// The **strip** (ADR 0227 D2): the pass as one row of chips, and the button that plays the whole loop
// along it. Split out for type length.
extension NameTheNotesSheet {

    /// One row of chips that scrolls sideways and keeps the current one in the middle (0227 D2), so the
    /// picker below stays put for 7 notes or 65, and switching sheets never loses the place. While the loop
    /// plays, the strip follows the chip being heard, and comes back to the current one when it stops.
    var strip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                playButton
                Text("\(noun.capitalized) \(active + 1) of \(labels.count)")
                    .font(.futura(.footnote, weight: .bold))
                    .monospacedDigit()
                Spacer()
                let unnamed = labels.filter { $0 == nil }.count
                Text(unnamed == 0 ? "All named" : "\(unnamed) to name")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(labels.indices, id: \.self) { index in
                            // A join sits between the two chips it joins, on the neck's sheet.
                            if mode == .fret, let join = NeckJoin.symbol(into: index, of: labels) {
                                Text(join)
                                    .font(.pocketMono(.caption))
                                    .fontWeight(.bold)
                                    .foregroundStyle(PocketColor.practice)
                                    .padding(.horizontal, -3)
                                    .accessibilityHidden(true)
                            }
                            chip(index)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 4)   // room for the ring on the chip being heard
                }
                .mask(stripFade)
                .onAppear { proxy.scrollTo(active, anchor: .center) }
                .onChange(of: active) {
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(active, anchor: .center) }
                }
                // Follow the loop, but not back to the current chip in the gap before a pass's first tap:
                // the strip would jump there and back once a pass.
                .onChange(of: hearing) {
                    guard let hearing else { return }
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(hearing, anchor: .center) }
                }
                .onChange(of: player.isPlaying) { _, playing in
                    guard !playing else { return }
                    hearing = nil
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(active, anchor: .center) }
                }
            }
        }
        .background {
            if player.isPlaying {
                HeardChipTracker(player: player, taps: request.taps.map(\.seconds)) { hearing = $0 }
            }
        }
    }

    /// **Play the loop** (0227 D2, added after the device check): the loop itself, the way *Train your
    /// ear* plays it, at its tempo and round until stopped, so the notes can be heard as a line and not
    /// only one at a time. Tapping a chip stops it and plays just that note.
    private var playButton: some View {
        Button {
            player.toggle()
        } label: {
            ZStack {
                Circle()
                    .fill(player.isPlaying ? PocketColor.practice : PocketColor.practice.opacity(0.14))
                if player.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(player.isPlaying ? PocketColor.background : PocketColor.practice)
                        .offset(x: player.isPlaying ? 0 : 1)   // optical-centre the play triangle
                }
            }
            .frame(width: 30, height: 30)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -7)
        .padding(.leading, -7)
        .disabled(player.isUnavailable)
        .accessibilityLabel(player.isPlaying ? "Stop the loop" : "Play the loop")
        .accessibilityIdentifier("naming.playLoop")
    }

    /// The strip fades out at both ends, so a chip cut off by the edge reads as "more this way".
    private var stripFade: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 18)
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 18)
        }
    }

    private func chip(_ index: Int) -> some View {
        let shown = chipText(index)
        let isActive = index == active
        return Button {
            select(index)
        } label: {
            VStack(spacing: 0) {
                Text("\(index + 1)")
                    .font(.futura(.caption2))
                    .monospacedDigit()
                Text(shown.text ?? "?")
                    .font(.futura(.subheadline, weight: shown.text == nil || shown.dim ? nil : .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isActive ? PocketColor.background
                             : shown.text == nil || shown.dim ? PocketColor.textSecondary : PocketColor.textPrimary)
            .padding(.horizontal, 8)
            .frame(minWidth: 46, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? PocketColor.practice : .clear))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isActive ? .clear : PocketColor.surfaceBorder))
            // The chip being heard while the loop plays: a ring just outside, so it reads on the filled
            // current chip as well as on the rest.
            .overlay {
                if index == hearing {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(PocketColor.practice, lineWidth: 2)
                        .padding(-3)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(noun.capitalized) \(index + 1), \(shown.text ?? "not named")")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// What a chip shows. On Fret & string a placed note is its string and fret ("B8"), and a name given
    /// by ear shows dimmed: it can't be drawn there. On By ear every answer is its name, a placed note
    /// read as the note it sounds (0227 D7).
    private func chipText(_ index: Int) -> (text: String?, dim: Bool) {
        guard let label = labels[index] else { return (nil, false) }
        if mode == .fret {
            // A chord of four notes or more is too long to spell out on a chip; its name says it.
            if label.frettedNotes.count > 3 {
                return (label.name(openMidi: tuning.openMidi, spelling: spelling), false)
            }
            if label.isOnTheNeck { return (fretText(label.frettedNotes), false) }
            return (label.name(openMidi: tuning.openMidi, spelling: spelling), true)
        }
        // On By ear a shape that spells no chord shows its interval or notes, dimmed: nothing to name.
        let unread = label.isOnTheNeck && label.earReading(openMidi: tuning.openMidi) == nil
        return (label.name(openMidi: tuning.openMidi, spelling: spelling), unread)
    }
}

/// While the strip's loop plays, which chip is being heard. **The one view in the sheet that reads the
/// clock** (ADR 0153): it redraws on its own, 30 times a second, and reports only when the chip changes.
private struct HeardChipTracker: View {
    let player: ContinuousLoopPlayer
    let taps: [TimeInterval]
    let onChange: (Int?) -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
            let heard = player.loopClock().flatMap { NamingStrip.heard($0, taps: taps) }
            Color.clear
                .onChange(of: heard, initial: true) { _, now in onChange(now) }
        }
        .accessibilityHidden(true)
    }
}
