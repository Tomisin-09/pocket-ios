import SwiftUI

// The **strip** (ADR 0227 D2): the pass as one row of chips, the button that plays the whole loop along
// it, and how many notes a tap plays. Split out for type length.
extension NameTheNotesSheet {

    /// One row of chips that scrolls sideways and keeps the current one in the middle (0227 D2), so the
    /// picker below stays put for 7 notes or 65, and switching sheets never loses the place. While the loop
    /// or a phrase plays, the strip follows the chip being heard, and comes back to the current one after.
    var strip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                playButton
                Text("\(noun.capitalized) \(active + 1) of \(labels.count)")
                    .font(.futura(.footnote, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                let unnamed = labels.filter { $0 == nil }.count
                Text(unnamed == 0 ? "All named" : "\(unnamed) to name")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                phraseMenu
            }
            let snagged = Set(pieceSnags.compactMap(\.note))
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
                            chip(index, snagged: snagged.contains(index))
                        }
                    }
                    .padding(.horizontal, 18)
                    // Room for the ring on the chip being heard, and above for a snag's mark (ADR 0234 D7).
                    .padding(.top, 9)
                    .padding(.bottom, 4)
                }
                .mask(PieceChip.rowFade)
                .onAppear { proxy.scrollTo(active, anchor: .center) }
                .onChange(of: active) {
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(active, anchor: .center) }
                }
                // Follow the loop, but not back to the current chip in the gap before a pass's first tap:
                // the strip would jump there and back once a pass. The loop keeps the heard chip in the
                // middle; a phrase moves the strip only as far as it must, so a short one doesn't swing it.
                .onChange(of: hearing) {
                    guard let hearing else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(hearing, anchor: following == .loop ? .center : nil)
                    }
                }
                .onChange(of: following) { _, now in
                    guard now == .nothing else { return }
                    hearing = nil
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(active, anchor: .center) }
                }
            }
        }
        .background { tracker }
    }

    /// What the ring follows now (`NamingStrip.Following`).
    var following: NamingStrip.Following {
        .now(loopPlaying: player.isPlaying, slicePlaying: player.isSlicePlaying, phrase: sounding)
    }

    /// The one leaf that reads a clock, there only while the ring has something to follow.
    @ViewBuilder private var tracker: some View {
        let seconds = taps.map(\.seconds)
        switch following {
        case .loop:
            HeardTapTracker { player.loopClock().flatMap { NamingStrip.heard($0, taps: seconds) } } report: {
                hearing = $0
            }
        case .phrase(let phrase):
            HeardTapTracker {
                player.sliceClock().flatMap { NamingStrip.heard($0, phrase: phrase, taps: seconds) }
            } report: {
                hearing = $0
            }
        case .nothing:
            EmptyView()
        }
    }

    /// **Play the loop** (0227 D2, added after the device check): the loop itself, the way *Train your
    /// ear* plays it, at its tempo and round until stopped, so the notes can be heard as a line and not
    /// only one at a time. Tapping a chip stops it and plays that chip's moment. While a phrase plays it
    /// stops the phrase, since eight notes slowed down can run for seconds.
    private var playButton: some View {
        let playing = following != .nothing
        return LoopPlayButton(isOn: playing, isLoading: player.isLoading, isDisabled: player.isUnavailable,
                              label: player.isPlaying ? "Stop the loop" : playing ? "Stop" : "Play the loop") {
            if case .phrase = following { player.stopSlice() } else { player.toggle() }
        }
        .padding(.vertical, -7)
        .padding(.leading, -7)
        .accessibilityIdentifier("naming.playLoop")
    }

    /// **How many notes a tap plays** (0227 D2, after the device check): the note alone, or the note and
    /// the ones before it, so it's heard arriving from the line rather than cut out of it. Always ending on
    /// the chip being named, which is the sound left in the ear when the finger goes to the neck.
    private var phraseMenu: some View {
        Menu {
            Section("Ending on the \(noun) you're naming") {
                Picker("Notes to hear", selection: $phraseNotes) {
                    ForEach(NamingStrip.phraseChoices, id: \.self) { count in
                        Text(count == 1 ? "Just the \(noun)" : "\(count) \(noun)s").tag(count)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text("Hear \(phraseNotes) \(noun)\(phraseNotes == 1 ? "" : "s")")
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(.futura(.caption, weight: .semibold))
            .foregroundStyle(PocketColor.practice)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .padding(.vertical, -7)
        .fixedSize()
        .accessibilityLabel("Notes to hear")
        .accessibilityValue("\(phraseNotes), ending on the \(noun) you're naming")
        .accessibilityIdentifier("naming.phraseLength")
    }

    /// A chip. **A tap plays it; a hold snags it** (ADR 0234 D7). They're separate gestures on a plain
    /// shape, never a `Button` with a hold added: a Button fires its tap on the hold's release too, so a
    /// snag would also play the note. VoiceOver can't find a hold, so snagging is a named action.
    private func chip(_ index: Int, snagged: Bool) -> some View {
        let shown = chipText(index)
        let isActive = index == active
        return PieceChip(number: index + 1, text: shown.text, dim: shown.dim, isCurrent: isActive)
        // The note just placed, which the marks are still on while the strip has moved past it (ADR
        // 0234 D3): outlined in dashes, the way a bend's landing is drawn on the neck.
        .overlay {
            if index == placedNote {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(PocketColor.practice, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
        }
        // The chip being heard while the loop plays.
        .heardRing(index == hearing)
        .overlay(alignment: .topTrailing) {
            if snagged {
                snagGlyph
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(PocketColor.background))
                    .offset(x: 5, y: -6)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { select(index) }
        // 0.4 s, the house hold (the loop row, panel headers, the speed bar).
        .onLongPressGesture(minimumDuration: 0.4) { toggleSnag(on: index) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(noun.capitalized) \(index + 1), \(shown.text ?? "not named")"
                            + (snagged ? ", snagged" : ""))
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { select(index) }
        .accessibilityAction(named: snagged ? "Take the snag off" : "Snag this \(noun)") { toggleSnag(on: index) }
        .accessibilityIdentifier("naming.chip.\(index)")
    }

    /// What a chip shows (`NamingStrip.chipText`): on Fret & string, read as it sits on the neck.
    private func chipText(_ index: Int) -> (text: String?, dim: Bool) {
        NamingStrip.chipText(labels[index], onTheNeck: mode == .fret, openMidi: tuning.openMidi, spelling: spelling)
    }
}
