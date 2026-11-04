import SwiftUI

/// **Watch it on the neck** (ADR 0254): a loop's piece, already named on the neck, played back on the neck
/// while the loop's own recording plays. A sheet for watching, not a practice mode (D1): no routine block, no
/// practice log row, no takes and no Journal note. Done closes it.
///
/// It also plays **a section, or the whole song** (ADR 0289), from the song map: every loop's piece in that
/// stretch, merged by `SectionWatch`, played straight through. Where two loops overlap, the later one shows,
/// and where no piece is placed, nothing lights.
///
/// From the top: the loop, its tuning, the neck (the whole lick in ink and the tap being heard lit, D4,
/// `PieceNeckView`), the taps in order as read-only chips with the one being heard ringed, then a play button
/// beside the −/+ tempo row. Only the recording sounds (D3). The board opens centred on the lick and moves
/// only when the heard tap leaves the frets in view (D5, `NeckFollow`).
///
/// Five doors open it, each behind `PieceNeck.canWatch(_:)` (D2), and each presents it from its body root,
/// never from a row, by a `StableRef` or a Bool (ADR 0090).
struct WatchOnNeckSheet: View {
    /// What every door calls it, and its icon: the same on all five.
    static let title = "Watch it on the neck"
    static let symbol = "eye"

    /// What's watched: one loop, or a stretch of a song (ADR 0289).
    enum Subject {
        case loop(Loop)
        /// A section, or all of the song when `isWholeSong`. `name` heads the sheet.
        case span(Song, name: String, isWholeSong: Bool)
    }

    private let subject: Subject
    @Environment(\.dismiss) private var dismiss
    /// Its own player, so the tempo starts at the loop's command (D6) and stopping here stops nothing else.
    @State private var player: ContinuousLoopPlayer
    /// The tap being heard while the loop plays.
    @State private var heard: Int?
    /// The fret the board centres on: the middle of the lick, then wherever following takes it.
    @State private var centre: Int?
    /// The board's width beside the string names, which following judges the frets in view by.
    @State private var boardWidth: Double = 0

    /// The taps to play, each with when it stops being heard.
    private let run: SectionWatch.Run
    private let labels: [PieceLabel?]
    private let openMidi: [Int]
    private let tuningLabel: String
    private let spelling: NoteSpelling
    /// *note* or *chord*, as the loop counts them.
    private let noun: String
    private let lick: Set<NeckSpot>
    /// How many taps are placed on the neck, which the stopped sheet says.
    private let onTheNeck: Int

    init(loop: Loop) {
        self.init(subject: .loop(loop), player: ContinuousLoopPlayer(loop: loop),
                  run: SectionWatch.run(of: loop.transcription, id: loop.uid, name: loop.name),
                  spelling: CountTheNotesModel.spelling(for: loop),
                  noun: loop.loopType == .chords ? "chord" : "note")
    }

    /// A section, or the whole song (ADR 0289): every piece in `start`…`end` (song seconds), merged. It opens
    /// at the record's tempo, since each loop in it can have its own command.
    init(song: Song, name: String, from start: TimeInterval, to end: TimeInterval,
         sources: [SectionWatch.Source], isWholeSong: Bool = false) {
        let run = SectionWatch.merge(sources, from: start, to: end)
        self.init(subject: .span(song, name: name, isWholeSong: isWholeSong),
                  player: ContinuousLoopPlayer(song: song, from: start, to: end), run: run,
                  spelling: NoteSpelling.forMusicalKey(song.musicalKey) ?? AppSettings.accidentalPreference,
                  noun: !run.sources.isEmpty && run.sources.allSatisfy(\.isChords) ? "chord" : "note")
    }

    private init(subject: Subject, player: ContinuousLoopPlayer, run: SectionWatch.Run, spelling: NoteSpelling,
                 noun: String) {
        self.subject = subject
        _player = State(initialValue: player)
        self.run = run
        let labels = run.labels
        let tuner = CountTheNotesModel.tunerTuning()
        self.labels = labels
        openMidi = run.openMidi ?? tuner.openMidi
        tuningLabel = run.tuningLabel ?? tuner.label
        self.spelling = spelling
        self.noun = noun
        lick = PieceNeck.spots(of: labels)
        onTheNeck = labels.filter { $0?.isOnTheNeck ?? false }.count
        _centre = State(initialValue: PieceNeck.span(of: labels).map { PieceNeck.centre(of: $0) })
    }

    /// Behind the plan (ADR 0256 D3): every route here meets the same wall, and nothing below is built
    /// until the plan is on.
    var body: some View {
        PlanGated(.watchOnNeck, presentation: .modal) { gatedScreen }
    }

    @ViewBuilder private var gatedScreen: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    Text(tuningLabel)
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                    neck
                    order
                    controls
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .background { tracker }
            }
            .navigationTitle(Self.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onChange(of: player.isPlaying) { _, playing in
            if !playing { heard = nil }
        }
        .onChange(of: heard) { _, now in follow(now) }
        .onDisappear { player.stop() }
        // Playing along hands-free is the point of it (D7).
        .keepAwakeDuringPractice()
    }

    /// What plays, as the controls say it.
    private var playing: String {
        switch subject {
        case .loop: "loop"
        case .span(_, _, let isWholeSong): isWholeSong ? "song" : "section"
        }
    }

    @ViewBuilder private var header: some View {
        switch subject {
        case .loop(let loop):
            LoopModeIdentityHeader(loop: loop)
        case .span(let song, let name, _):
            WatchSpanHeader(song: song, name: name, run: run)
        }
    }

    // MARK: - The neck

    /// One element for VoiceOver: the tap being heard in words, or how many are on the neck while stopped.
    /// It's read when the neck is reached, never announced on every note.
    private var neck: some View {
        PieceNeckView(labels: labels, openMidi: openMidi, spelling: spelling, lick: lick, heard: heard,
                      centre: centre)
            .onGeometryChange(for: Double.self) { Double($0.size.width) } action: {
                // A piece that mutes a string has the ✕ column beside the names too (ADR 0262 D4).
                let pinned = PieceNeck.mutedStrings(of: labels).isEmpty ? 0 : NeckGeometry.pinnedWidth
                boardWidth = $0 - Double(NeckGeometry.namesWidth + NeckGeometry.namesSpacing + pinned)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("The neck")
            .accessibilityValue(heardWords ?? "\(onTheNeck) on the neck")
            .accessibilityIdentifier("watch.neck")
    }

    /// The tap being heard, said the way a player would (`PieceNeck.words`), or `nil` while stopped.
    private var heardWords: String? {
        heard.map { PieceNeck.words(for: $0, of: labels, openMidi: openMidi, spelling: spelling) }
    }

    /// Following (D5): the board moves only when the heard tap's frets leave the frets in view, and not for
    /// a tap that isn't on the neck.
    private func follow(_ heard: Int?) {
        guard let heard, let frets = PieceNeck.frets(of: heard, in: labels),
              let target = NeckFollow.target(current: centre, heard: frets, width: boardWidth) else { return }
        centre = target
    }

    /// The one leaf that reads a clock (ADR 0153), there only while the loop plays.
    @ViewBuilder private var tracker: some View {
        if player.isPlaying {
            HeardTapTracker { heardNow() } report: { heard = $0 }
        }
    }

    /// The tap heard at this instant of the loop's clock, or `nil` in a gap (ADR 0289).
    private func heardNow() -> Int? {
        guard let reading = player.loopClock(), let now = TapTally.heardPosition(reading) else { return nil }
        return run.heard(at: reading.regionStart + now.within)
    }

    // MARK: - The taps in order

    /// The taps as Name the notes' chips read them on the neck, with the joins between them, read only: the
    /// one being heard is ringed and kept in the middle. Over them, where the loop is and what's heard.
    private var order: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(heard.map { "\(noun.capitalized) \($0 + 1) of \(labels.count)" } ?? tapCount)
                    .font(.futura(.footnote, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                Text(heardWords ?? "\(onTheNeck) on the neck")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .multilineTextAlignment(.trailing)
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(labels.indices, id: \.self) { index in
                            // In a section of several loops, each one's name where its taps begin (ADR 0289).
                            // One loop's name is the header's already.
                            if case .span = subject, run.sources.count > 1,
                               let source = run.source(startingAt: index) {
                                Text(source.name)
                                    .font(.futura(.caption2, weight: .bold))
                                    .foregroundStyle(PocketColor.textSecondary)
                                    .lineLimit(1)
                                    .padding(.leading, index == 0 ? 0 : 10)
                                    .accessibilityHidden(true)
                            }
                            if let join = NeckJoin.symbol(into: index, of: labels) {
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
                    // Room for the ring on the chip being heard.
                    .padding(.vertical, 5)
                }
                .mask(PieceChip.rowFade)
                .onChange(of: heard) { _, now in
                    guard let now else { return }
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(now, anchor: .center) }
                }
            }
        }
    }

    /// *"11 notes"*, while nothing is heard.
    private var tapCount: String { "\(labels.count) \(noun)\(labels.count == 1 ? "" : "s")" }

    private func chip(_ index: Int) -> some View {
        let shown = NamingStrip.chipText(labels[index], onTheNeck: true, openMidi: openMidi, spelling: spelling)
        return PieceChip(number: index + 1, text: shown.text, dim: shown.dim)
            .heardRing(index == heard)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(noun.capitalized) \(index + 1), \(shown.text ?? "not named")")
            .accessibilityAddTraits(index == heard ? .isSelected : [])
    }

    // MARK: - Play and tempo

    /// Compact, so the chips stay above the fold on a small phone: a play button, what the audio is doing,
    /// and the −/+ tempo row.
    private var controls: some View {
        HStack(spacing: 12) {
            LoopPlayButton(isOn: player.isPlaying, isLoading: player.isLoading, isDisabled: player.isUnavailable,
                           label: player.isPlaying ? "Stop the \(playing)" : "Play the \(playing)", diameter: 52) {
                LoopTransport.toggle(player, recorder: nil, onStopped: {})
            }
            .accessibilityIdentifier("watch.play")
            Text(statusLine)
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            LoopTempoControl(player: player, buttonSize: 28, spacing: 6, valueWidth: 56)
        }
    }

    /// What the audio is doing, never a score.
    private var statusLine: String {
        if player.isUnavailable { return "Audio unavailable — the song file moved or was deleted." }
        if player.isLoading { return "Loading…" }
        if player.isPlaying { return "Playing at \(player.percent)%. Play along with it." }
        return "Tap to play the \(playing). It goes round until you stop it."
    }
}
