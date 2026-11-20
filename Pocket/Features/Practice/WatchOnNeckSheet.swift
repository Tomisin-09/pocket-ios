import SwiftUI

/// **Watch it on the neck** (ADR 0254): a loop's piece, already named on the neck, played back on the neck
/// while the loop's own recording plays. A sheet for watching, not a practice mode (D1): no routine block, no
/// practice log row, no takes and no Journal note. Done closes it.
///
/// It also plays **what was picked on the song map** (ADR 0289, ADR 0308): a section from its name's hold
/// menu, or any pieces and sections picked, from the start of the first to the end of the last. Only the
/// picks light (0308 D3), merged by `SectionWatch`: where two overlap, the later one shows, a piece in the
/// stretch that isn't picked plays and stays dark, and where nothing picked is placed, nothing lights.
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
        /// What was picked on the song map (ADR 0308): its title heads the sheet.
        case span(Song, SongMapPicking.Watch)
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
    /// While picks play (ADR 0308): the bar being played, and the piece that isn't picked when one is.
    @State private var moment = SpanMoment()

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
    /// The chords the song is on under the picks, from the whole chords lane (ADR 0308 D4). None for a
    /// loop's own sheet: whether that colours its notes is open in the ADR.
    private let sectionChords: [SectionWatch.Chord]
    /// Edit song, open from **Set the key** (ADR 0308 D6).
    @State private var settingKey = false

    init(loop: Loop) {
        self.init(subject: .loop(loop), player: ContinuousLoopPlayer(loop: loop),
                  run: SectionWatch.run(of: loop.heardTranscription, id: loop.uid, name: loop.name),
                  spelling: CountTheNotesModel.spelling(for: loop),
                  noun: loop.loopType == .chords ? "chord" : "note")
    }

    /// What was picked on the song map (ADR 0308): the pieces `watch.lit` names, merged over its stretch. It
    /// opens at the record's tempo (0289 D7), since each loop in it can have its own command.
    init(song: Song, watch: SongMapPicking.Watch, sources: [SectionWatch.Source]) {
        let run = SectionWatch.merge(sources.filter { watch.lit.contains($0.id) }, from: watch.start, to: watch.end)
        self.init(subject: .span(song, watch),
                  player: ContinuousLoopPlayer(song: song, from: watch.start, to: watch.end), run: run,
                  spelling: NoteSpelling.forMusicalKey(song.heardKey) ?? AppSettings.accidentalPreference,
                  noun: !run.sources.isEmpty && run.sources.allSatisfy(\.isChords) ? "chord" : "note",
                  chords: SectionWatch.chords(sources, from: watch.start, to: watch.end))
    }

    private init(subject: Subject, player: ContinuousLoopPlayer, run: SectionWatch.Run, spelling: NoteSpelling,
                 noun: String, chords: [SectionWatch.Chord] = []) {
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
        sectionChords = chords
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
                    if let chords, case .span(let song, let watch) = subject {
                        WatchChordRow(chords: chords,
                                      current: player.isPlaying ? moment.chord
                                        : chords.index(at: watch.start) ?? (chords.chords.isEmpty ? nil : 0),
                                      keyName: song.heardKey.displayName, onSetKey: { settingKey = true })
                    }
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
            if !playing {
                heard = nil
                moment = SpanMoment()
            }
        }
        .onChange(of: heard) { _, now in follow(now) }
        .sheet(isPresented: $settingKey) {
            if case .span(let song, _) = subject { SongEditSheet(song: song) }
        }
        .onDisappear { player.stop() }
        // Playing along hands-free is the point of it (D7).
        .keepAwakeDuringPractice()
    }

    @ViewBuilder private var header: some View {
        switch subject {
        case .loop(let loop):
            LoopModeIdentityHeader(loop: loop)
        case .span(let song, let watch):
            WatchSpanHeader(song: song, watch: watch, run: run)
        }
    }

    // MARK: - The neck

    /// One element for VoiceOver: the tap being heard in words, or how many are on the neck while stopped.
    /// It's read when the neck is reached, never announced on every note.
    private var neck: some View {
        // The heard note filled with its chord's colour, and the lick's other notes over that chord tinted with
        // it (ADR 0308 D4). Where no chord plays, the neck is drawn as it always was.
        let byTap = tapChords
        let heardChord = heard.flatMap { byTap.indices.contains($0) ? byTap[$0] : nil }
        let chordColour = colour(ofChord: heardChord)
        let overIt = chordColour == nil ? [] : PieceNeck.spots(of: byTap.indices.filter { byTap[$0] == heardChord }
            .map { labels[$0] })
        return PieceNeckView(labels: labels, openMidi: openMidi, spelling: spelling, lick: lick, heard: heard,
                             centre: centre, tinted: overIt)
            .environment(\.neckAccent, chordColour ?? PocketColor.practice)
            .onGeometryChange(for: Double.self) { Double($0.size.width) } action: {
                // A piece that mutes a string has the ✕ column beside the names too (ADR 0262 D4).
                let pinned = PieceNeck.mutedStrings(of: labels).isEmpty ? 0 : NeckGeometry.pinnedWidth
                boardWidth = $0 - Double(NeckGeometry.namesWidth + NeckGeometry.namesSpacing + pinned)
            }
            .overlay {
                // A piece in the stretch that isn't picked plays, and stays dark (ADR 0308 D3).
                if heard == nil, let notPicked = moment.notPicked {
                    Text(notPicked)
                        .font(.futura(.footnote, weight: .semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(PocketColor.background.opacity(0.9)))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("The neck")
            .accessibilityValue(heardWords ?? moment.notPicked ?? "\(onTheNeck) on the neck")
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
            HeardTapTracker { songTimeNow().flatMap(run.heard(at:)) } report: { heard = $0 }
            if case .span(_, let watch) = subject {
                HeardTapTracker {
                    songTimeNow().map {
                        SpanMoment(bar: watch.bar(at: $0), notPicked: watch.notPicked(at: $0),
                                   chord: chords?.index(at: $0))
                    }
                        ?? SpanMoment()
                } report: { moment = $0 }
            }
        }
    }

    /// This instant of the loop's clock, in song seconds, as the taps are counted (ADR 0289). The tap heard
    /// then is `run.heard(at:)`, or `nil` in a gap.
    private func songTimeNow() -> TimeInterval? {
        guard let reading = player.loopClock(), let now = TapTally.heardPosition(reading) else { return nil }
        return reading.regionStart + now.within
    }

    // MARK: - The taps in order

    /// The taps as Name the notes' chips read them on the neck, with the joins between them, read only: the
    /// one being heard is ringed and kept in the middle. Over them, where the loop is and what's heard.
    private var order: some View {
        // Read once a draw, not once a chip.
        let chordsNow = chords
        let byTap = chordsNow?.chordIndices(of: run.taps.map(\.seconds)) ?? []
        return VStack(alignment: .leading, spacing: 4) {
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
                            chip(index, chords: chordsNow, byTap: byTap)
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

    // MARK: - Play and tempo

    /// Compact, so the chips stay above the fold on a small phone: a play button, what the audio is doing,
    /// and the −/+ tempo row.
    private var controls: some View {
        HStack(spacing: 12) {
            LoopPlayButton(isOn: player.isPlaying, isLoading: player.isLoading, isDisabled: player.isUnavailable,
                           label: playLabel, diameter: 52) {
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
    /// *Play the loop*, or for picks *Play from bar 39* (ADR 0308 D2).
    private var playLabel: String {
        switch subject {
        case .loop: player.isPlaying ? "Stop the loop" : "Play the loop"
        case .span(_, let watch): player.isPlaying ? "Stop" : watch.playLabel
        }
    }

    private var statusLine: String {
        if player.isUnavailable { return "Audio unavailable — the song file moved or was deleted." }
        if player.isLoading { return "Loading…" }
        if player.isPlaying {
            // The bar counter, while picks play (ADR 0308 D2).
            let bar = moment.bar.map { "Bar \($0) · playing" } ?? "Playing"
            return "\(bar) at \(player.percent)%. Play along with it."
        }
        switch subject {
        case .loop: return "Tap to play the loop. It goes round until you stop it."
        case .span(_, let watch):
            return "Tap to \(watch.playLabel.prefix(1).lowercased() + watch.playLabel.dropFirst()). "
                + "It goes round until you stop it."
        }
    }
}

// MARK: - The chords (ADR 0308 D4–D6)

/// Apart from the struct's body only for its length budget; `private` still reaches across in this file.
extension WatchOnNeckSheet {

    /// The chords under the picks, read against the key you hear (ADR 0308 D4–D6). Read live, so a key set
    /// in Edit song colours them at once.
    private var chords: WatchChords? {
        guard case .span(let song, _) = subject, !sectionChords.isEmpty else { return nil }
        return WatchChords(sectionChords, key: song.heardKey,
                           spelling: NoteSpelling.forMusicalKey(song.heardKey) ?? AppSettings.accidentalPreference)
    }

    /// Each tap's chord, by when it's played.
    private var tapChords: [Int?] { chords?.chordIndices(of: run.taps.map(\.seconds)) ?? [] }

    /// A chord's colour, or `nil` with no key: then nothing is coloured (D6).
    private func colour(ofChord index: Int?) -> Color? {
        guard let index, let chords, chords.chords.indices.contains(index) else { return nil }
        return chords.chords[index].numeral.map { PocketColor.chord(degree: $0.degree) }
    }

    /// A chip, wearing its chord's colour, with the chord's name and numeral over the first chip of each
    /// chord (ADR 0308 D4). Every chip keeps the line's room when there are chords, so they stay in a row.
    @ViewBuilder private func chip(_ index: Int, chords: WatchChords?, byTap: [Int?]) -> some View {
        let shown = NamingStrip.chipText(labels[index], onTheNeck: true, openMidi: openMidi, spelling: spelling)
        let chord = byTap.indices.contains(index) ? byTap[index] : nil
        let tint = chord.flatMap { chords?.chords[$0].numeral }.map { PocketColor.chord(degree: $0.degree) }
        let chipView = PieceChip(number: index + 1, text: shown.text, dim: shown.dim, tint: tint)
            .heardRing(index == heard)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(noun.capitalized) \(index + 1), \(shown.text ?? "not named")")
            .accessibilityAddTraits(index == heard ? .isSelected : [])
        if let chords {
            VStack(alignment: .leading, spacing: 3) {
                Text(WatchChords.startsAChord(byTap, at: index) ? chord.map { chords.chords[$0].title } ?? " " : " ")
                    .font(.futura(.caption2, weight: .bold))
                    .foregroundStyle(tint ?? PocketColor.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityHidden(true)
                chipView
            }
        } else {
            chipView
        }
    }
}

/// What the picks' clock reports while they play (ADR 0308 D2, D3): one value, so the sheet redraws only
/// when the bar or the dark piece changes.
private struct SpanMoment: Equatable {
    var bar: Int?
    var notPicked: String?
    var chord: Int?
}
