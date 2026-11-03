import SwiftUI

/// Set an unknown (or wrong) tempo, behind the player's metronome button (ADR 0024). The sheet opens
/// on **Find the tempo**, rung 2 of ADR 0004's chain, and the rest follows from the tempo it finds
/// (ADR 0284): hear it with the click, put it right with Half or Double, then line up the bar. Tap
/// along, Type a tempo and Tap through the song are listed under it as the other ways.
///
/// - Taps read the live **song-time** (`PracticeAudioEngine.currentTime`), so tapping inside a loop or
///   at a reduced speed still reads the song's true tempo.
/// - "Mark the 1" stamps the bar-1 downbeat, the phase anchor the beat grid needs (ADR 0022).
///
/// Nothing reaches the song until Done (ADR 0004). The sheet hands back a full-precision BPM via
/// `onCommit`; the model stores it in `Song.preciseBPM` (grid) and mirrors the rounded value into
/// `Song.bpm` (display). Play and the click sit above the form, and the click plays the sheet's
/// values before Done (ADR 0283).
struct BPMSheet: View {
    /// The live engine, read for `currentTime` (taps, Mark the 1) and `isPlaying`, and driven for
    /// play/pause so the player can listen while setting the tempo.
    let engine: PracticeAudioEngine
    /// The song's current precise/rounded tempo, shown until the sheet has one of its own.
    let currentBPM: Double?
    /// The song's current downbeat ("the 1"), so reopening the sheet (e.g. after placing it on the
    /// waveform) shows the value that's set.
    let currentDownbeat: TimeInterval?
    /// The song's current time signature (ADR 0051), to prefill the bar. Default 4/4.
    let currentBeatsPerBar: Int
    let currentNoteValue: Int
    /// The song's beat map and the way to tap one (ADR 0281). `nil` in previews.
    let beatMap: BeatMapHooks?
    /// The song's click, played from the sheet (ADR 0283). `nil` in previews.
    let click: TempoClickHooks?
    /// `(bpm, downbeatSeconds, beatsPerBar, noteValue)`: bpm/downbeat may be `nil` (set only what's
    /// given); the time signature always carries a value (the bar's selection).
    let onCommit: (Double?, TimeInterval?, Int, Int) -> Void
    /// "Set the 1 on the waveform": commits the current BPM (if any) and hands off to the on-waveform
    /// downbeat handle. The sheet dismisses first.
    let onSetOnWaveform: (Double?) -> Void
    /// On-device tempo estimate from the audio (ADR 0004, rung 2). Returns the estimate, with (when
    /// found) a downbeat phase in seconds and the envelope behind it, or `nil` when there's no
    /// analysable source or no confident read.
    let onEstimate: () async -> TempoEstimator.Reading?

    @Environment(\.dismiss) private var dismiss

    /// The tempo chosen in the sheet and where it came from (ADR 0284 D2). `nil` ⇒ the song's own
    /// stands, and Done leaves it alone.
    @State private var draft: TempoDraft?
    /// The bar-1 downbeat ("the 1"), and the beat of the bar the player has heard it on (ADR 0283
    /// D3). Nothing placed ⇒ leave phase as-is.
    @State private var one: DownbeatChoice
    /// True while the off-main estimate is running, to show progress and avoid re-entry.
    @State private var isEstimating = false
    /// True when the estimate found no confident tempo (flat/ambient material).
    @State private var estimateFailed = false
    /// The chosen meter (ADR 0051), seeded from the song, committed on Done.
    @State private var timeSignature: TimeSignature
    /// The sheet's click switch, seeded from the song's click (ADR 0283 D1).
    @State private var clickOn: Bool
    /// The switch as Done left it, for the song to keep; `nil` until Done.
    @State private var keptClick: Bool?
    /// The pages pushed over the sheet. The click is quiet while one is up (ADR 0284 D6).
    @State private var path: [TempoSheetPage] = []
    /// *Type a tempo*'s field, open in place, and what's in it.
    @State private var typing = false
    @State private var typedText = ""

    init(engine: PracticeAudioEngine, currentBPM: Double?, currentDownbeat: TimeInterval?,
         currentBeatsPerBar: Int = 4, currentNoteValue: Int = 4, beatMap: BeatMapHooks? = nil,
         click: TempoClickHooks? = nil,
         onCommit: @escaping (Double?, TimeInterval?, Int, Int) -> Void,
         onSetOnWaveform: @escaping (Double?) -> Void,
         onEstimate: @escaping () async -> TempoEstimator.Reading?) {
        self.engine = engine
        self.currentBPM = currentBPM
        self.currentDownbeat = currentDownbeat
        self.currentBeatsPerBar = currentBeatsPerBar
        self.currentNoteValue = currentNoteValue
        self.beatMap = beatMap
        self.click = click
        self.onCommit = onCommit
        self.onSetOnWaveform = onSetOnWaveform
        self.onEstimate = onEstimate
        _one = State(initialValue: DownbeatChoice(placed: currentDownbeat))
        _timeSignature = State(initialValue: TimeSignature.forStored(
            beats: currentBeatsPerBar, noteValue: currentNoteValue, accentBeats: []))
        _clickOn = State(initialValue: click?.wasOn ?? false)
    }

    private var hasBeatMap: Bool { !(beatMap?.beatTimes.isEmpty ?? true) }

    /// What heads the sheet: Find the tempo, the tempo, or the beats (ADR 0284 D1, D2).
    private var top: TempoSheetTop {
        TempoSheetTop(draft: draft, isListening: isEstimating, hasBeatMap: hasBeatMap, songBPM: currentBPM)
    }

    /// The BPM Done would commit (full precision), or `nil` to leave the song's alone.
    private var resolvedBPM: Double? { draft?.bpm }

    /// The 1 Done commits: the placed one, moved to the beat chosen along the grid Done would leave
    /// (ADR 0283 D3). A tempo given replaces a beat map, so the map counts only while none is.
    private var chosenDownbeat: TimeInterval? {
        one.seconds(beatsPerBar: timeSignature.beats, bpm: resolvedBPM ?? currentBPM,
                    map: resolvedBPM == nil ? beatMap?.beatTimes ?? [] : [],
                    duration: beatMap?.duration ?? 0)
    }

    /// Something to count the beats from: a tempo, given here or the song's.
    private var hasTempo: Bool { (resolvedBPM ?? currentBPM) != nil }

    private var timeSignatureChanged: Bool {
        timeSignature.beats != currentBeatsPerBar || timeSignature.noteValue != currentNoteValue
    }

    private var canCommit: Bool { resolvedBPM != nil || one.placed != nil || timeSignatureChanged }

    /// What the click still needs before it can play, said in the strip, or `nil` when it can
    /// (ADR 0284 D3).
    private var clickWaitsFor: String? {
        if !hasTempo { return "The click comes with a tempo" }
        if (chosenDownbeat ?? currentDownbeat) == nil { return "Mark the 1 to hear the click" }
        return nil
    }

    /// What the click plays, so it follows every change in the sheet (ADR 0283 D1). Quiet while a
    /// page is pushed, where it would play the tempo being replaced (ADR 0284 D6).
    private var clickPreview: TempoClickHooks.Values {
        .init(isOn: clickOn && path.isEmpty, bpm: resolvedBPM, downbeat: chosenDownbeat,
              beatsPerBar: timeSignature.beats)
    }

    private var summary: String {
        TempoDraft.summary(beatsPerBar: timeSignature.beats, noteValue: timeSignature.noteValue,
                           name: timeSignature.name, downbeat: chosenDownbeat)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                TempoSheetTopSection(top: top, summary: summary, replacesBeats: hasBeatMap,
                                     hasOne: chosenDownbeat != nil,
                                     estimateFailed: estimateFailed, beatMap: beatMap,
                                     onFind: findTheTempo, onScale: rescale(by:),
                                     onUseOneTempo: useOneTempo)
                if hasTempo {
                    TheOneSection(signature: $timeSignature, one: $one, onMark: markTheOne,
                                  onSetOnWaveform: setTheOneOnTheWaveform)
                }
                SteadyTempoSection()
                OtherWaysSection(hasTempo: hasTempo,
                                 offersFindAgain: top.offersFindAgain, offersTapThrough: beatMap != nil,
                                 typing: $typing, typedText: $typedText, showing: top.shown?.bpm,
                                 onFind: findTheTempo, onUseTyped: useTyped)
            }
            .tempoSheetStyle()
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .top, spacing: 0) {
                TempoSheetTransport(engine: engine, clickOn: $clickOn, clickWaitsFor: clickWaitsFor)
            }
            .navigationTitle("Set tempo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.futura(.body))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        keptClick = clickOn
                        onCommit(resolvedBPM, chosenDownbeat, timeSignature.beats, timeSignature.noteValue)
                        dismiss()
                    }
                    .font(.futura(.body, weight: .bold))
                    .tint(PocketColor.waveformAccent)
                    .disabled(!canCommit)
                }
            }
            .navigationDestination(for: TempoSheetPage.self) { page in
                switch page {
                case .tapAlong:
                    TapAlongView(engine: engine, onUse: useTapped)
                case .tapThrough:
                    if let beatMap { TapThroughView(engine: engine, hooks: beatMap) }
                }
            }
        }
        .onChange(of: clickPreview) { _, values in click?.preview(values) }
        // On the stack, not the form, so pushing a page doesn't end the preview.
        .onDisappear { click?.end(keptClick) }
        .presentationDetents([.medium, .large])
    }

    // MARK: Choosing a tempo

    /// A tempo found, tapped or typed. It heads the sheet, and the click comes on to check it by,
    /// once there's a 1 to count from (ADR 0284 D3).
    private func choose(_ chosen: TempoDraft) {
        draft = chosen
        if clickWaitsFor == nil { clickOn = true }
    }

    private func findTheTempo() {
        typing = false
        Task { await runEstimate() }
    }

    /// Run the on-device estimate. It heads the sheet with its 1 placed, both still only a proposal
    /// until Done (ADR 0004). A `nil` result means no analysable source or no confident read, which
    /// the sheet says rather than silently doing nothing.
    private func runEstimate() async {
        guard !isEstimating else { return }
        isEstimating = true
        estimateFailed = false
        let result = await onEstimate()
        isEstimating = false
        guard let result else {
            estimateFailed = true
            return
        }
        if let phase = result.estimate.downbeatSeconds { one.placed = phase }
        choose(TempoDraft(reading: result))
    }

    /// **Half** or **Double** (ADR 0284 D2) on the tempo shown. An estimate is counted again and its 1
    /// placed again, unless the player has placed one since, or chosen another beat for it (ADR
    /// 0283 D3), which then stays where they heard it. Any other tempo keeps its 1.
    private func rescale(by factor: Double) {
        guard let shown = top.shown, let scaled = shown.scaled(by: factor) else { return }
        if let reading = shown.reading, let next = scaled.reading {
            one.placed = reading.downbeat(after: next, current: chosenDownbeat)
        }
        draft = scaled
        haptic(.light)
    }

    private func useTapped(_ bpm: Double) {
        path.removeAll()
        estimateFailed = false
        choose(TempoDraft(bpm: bpm, source: .tapped))
    }

    private func useTyped(_ bpm: Double) {
        typing = false
        typedText = ""
        estimateFailed = false
        choose(TempoDraft(bpm: bpm, source: .typed))
    }

    private func useOneTempo() {
        beatMap?.useOneTempo()
        dismiss()
    }

    // MARK: The 1

    private func markTheOne() {
        one.placed = engine.currentTime
        haptic(.light)
    }

    private func setTheOneOnTheWaveform() {
        let bpm = resolvedBPM
        dismiss()
        onSetOnWaveform(bpm)
    }
}

/// The pages the tempo sheet pushes (ADR 0284 D5, D6).
enum TempoSheetPage: Hashable {
    case tapAlong
    case tapThrough
}
