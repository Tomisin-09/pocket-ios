import SwiftUI

/// The core practice screen (design brief §4.1): a fixed practice cockpit over a
/// scrollable reference area, driven (for now) by mock song data plus a generated
/// dev audio sample. Real playback runs through `PracticeAudioEngine`; the three
/// transport modes are live as a gesture engine (Scroll/Tap/Fine — ADRs 0003,
/// 0005). Loop capture is a keyboard-free confirm step then a naming sheet. Real
/// file import and the asymmetric speed scale are later iterations. Sections
/// live in `WaveformSections.swift`; shared chrome in `WaveformChrome.swift`.
struct WaveformPracticeView: View {

    /// Transport interaction modes — pills in the transport bar (brief §4.1).
    enum InteractionMode: String, CaseIterable, Identifiable {
        case scroll = "Scroll"
        case tap = "Tap"
        case fine = "Fine"
        var id: String { rawValue }

        /// One-line description shown under the speed bar.
        var blurb: String {
            switch self {
            case .scroll: "Tap to set the playhead · hold to drop a marker"
            case .tap: "Drag to scrub · tap to set loop start, tap again to close"
            case .fine: "Drag the blue handles to fine-tune the loop bounds"
            }
        }
    }

    private let song = WaveformMock.song

    // UI state (visual only in this iteration — no engine wired yet).
    @State private var speed: Double = 1.0
    @State private var mode: InteractionMode = .scroll
    @State private var songInfoExpanded = false   // demoted to the scroll area
    @State private var loopsExpanded = true
    @State private var markersExpanded = false
    @State private var repeatOn = true

    // Audio engine + the waveform amplitudes it loaded from the sample.
    @State private var engine = PracticeAudioEngine()
    @State private var amplitudes: [Double] = WaveformMock.song.amplitudes

    // Loops/markers are mutable so they can be activated, renamed and deleted.
    @State private var loops = WaveformMock.song.loops
    @State private var markers = WaveformMock.song.markers
    @State private var activeLoopID: WaveformMock.Loop.ID? = WaveformMock.song.loops.first?.id
    @State private var editingLoop: WaveformMock.Loop?
    @State private var editingMarker: WaveformMock.Marker?

    /// Tap mode: the start of the loop being captured (the green forming
    /// region), awaiting its closing tap.
    @State private var pendingStart: Double?
    /// The captured loop awaiting confirmation (drives the ConfirmBar). Bounds
    /// are mutable so Fine handles drag them live; `fromFine` shows the blue
    /// handles; a non-nil `editingLoopID` means we're adjusting an existing
    /// loop's range rather than creating one.
    @State private var capture: CaptureDraft?
    /// The confirmed loop awaiting a name (drives the naming sheet).
    @State private var namingDraft: NamingDraft?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Read-only BPM display: round(songBPM × speed) — brief §4.1 speed bar.
    /// `nil` when the song has no known tempo (see ADR 0004); the speed
    /// multiplier still works regardless.
    private var displayedBPM: Int? {
        song.bpm.map { Int((Double($0) * speed).rounded()) }
    }

    /// The loop currently loaded into the transport/waveform, if any.
    private var activeLoop: WaveformMock.Loop? { loops.first { $0.id == activeLoopID } }

    /// Live playhead as a fraction of the song (0...1), driven by the engine.
    private var playheadFraction: Double {
        engine.duration > 0 ? engine.currentTime / engine.duration : 0
    }

    /// Effective song length — the engine's once loaded, else the mock's.
    private var duration: TimeInterval {
        engine.duration > 0 ? engine.duration : song.duration
    }

    /// The Fine-mode selection to render (blue handles), if one is being defined.
    private var fineSelection: (start: Double, end: Double)? {
        guard let capture, capture.fromFine else { return nil }
        return (capture.start, capture.end)
    }

    /// True while adjusting an existing loop's range — the reference area dims to
    /// focus the waveform.
    private var isRangeEditing: Bool { capture?.editingLoopID != nil }

    /// The confirm pill shows while a region is captured but not yet being named.
    private var showConfirm: Bool { capture != nil && namingDraft == nil }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        ZStack {
            PocketColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Fixed practice surface — the controls you touch constantly,
                // pinned so they never scroll away (brief items 1, 3–8).
                VStack(spacing: 16) {
                    SongStrip(song: song)                                    // 1
                    SpeedBar(speed: $speed, displayedBPM: displayedBPM,      // 3
                             onSetBPM: setBPM)
                    ModeDescriptionLine(mode: mode)                          // 4
                    WaveformView(amplitudes: amplitudes,                     // 5
                                 playheadFraction: playheadFraction,
                                 loop: activeLoop,
                                 mode: mode,
                                 formingStart: pendingStart,
                                 fineSelection: fineSelection,
                                 playheadLabel: timecode(engine.currentTime),
                                 onSeek: seekToFraction,
                                 onDropMarker: dropMarker,
                                 onTapPunch: tapPunch,
                                 onScrub: seekToFraction,
                                 onMoveHandle: moveFineHandle)
                        // 9. Icon-only confirm pill, floating over the waveform
                        //    once a region is captured (hidden while naming).
                        .overlay(alignment: .bottom) {
                            if showConfirm {
                                ConfirmPopup(isEditing: capture?.editingLoopID != nil,
                                             onConfirm: confirmCapture,
                                             onCancel: cancelCapture)
                                    .padding(.bottom, 8)
                                    .transition(reduceMotion ? .opacity
                                                : .scale(scale: 0.85).combined(with: .opacity))
                            }
                        }
                    TimeRuler(duration: duration)                            // 6
                    Minimap(song: song, activeLoop: activeLoop, markers: markers, // 7
                            fineSelection: fineSelection,
                            playheadFraction: playheadFraction,
                            onSeek: seekToFraction)
                    TransportBar(isPlaying: engine.isPlaying,                // 8
                                 onPlayPause: engine.togglePlay,
                                 repeatOn: $repeatOn,
                                 mode: $mode,
                                 currentTime: engine.currentTime,
                                 loop: activeLoop,
                                 onCapture: quickCapture)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)

                // Hairline boundary between the fixed surface and the scroll area.
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                // Scrollable reference — loops, markers, then song info (demoted
                // to the bottom, collapsed by default). Dimmed + disabled while
                // adjusting a loop's range, to focus the waveform.
                ScrollView {
                    VStack(spacing: 16) {
                        LoopsPanel(loops: loops, expanded: $loopsExpanded,       // 10
                                   activeLoopID: activeLoopID, isPlaying: engine.isPlaying,
                                   onActivate: activate, onEdit: { editingLoop = $0 })
                        MarkersPanel(markers: markers, expanded: $markersExpanded, // 11
                                     onSeek: seekToMarker, onEdit: { editingMarker = $0 })
                        SongInfoPanel(song: song, expanded: $songInfoExpanded)   // 2
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .opacity(isRangeEditing ? 0.25 : 1)
                .disabled(isRangeEditing)
                .animation(.easeOut(duration: 0.2), value: isRangeEditing)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $editingLoop) { loop in
            LoopEditSheet(loop: loop, onSave: updateLoop, onDelete: { deleteLoop(loop) },
                          onAdjustRange: { startRangeEdit(loop) })
        }
        .sheet(item: $editingMarker) { marker in
            MarkerEditSheet(marker: marker, onSave: updateMarker, onDelete: { deleteMarker(marker) })
        }
        .sheet(item: $namingDraft, onDismiss: namingDismissed) { draft in
            LoopNameSheet(range: rangeString(draft.start, draft.end), onSave: saveNamed)
        }
        .task { await loadSample() }
        .onChange(of: speed) { _, newValue in engine.setRate(newValue) }
        .onChange(of: mode) { _, newMode in modeChanged(to: newMode) }
    }

    /// Generate the dev sample and hand it to the engine (skipped in previews to
    /// keep the canvas light and avoid spinning up AVAudioEngine).
    private func loadSample() async {
        guard !isPreview, engine.duration == 0 else { return }
        guard let sample = try? SampleToneGenerator.makeSample(duration: song.duration) else { return }
        amplitudes = sample.amplitudes
        try? engine.load(url: sample.url)
        engine.setRate(speed)
    }
}

// MARK: - Actions & gesture handlers

extension WaveformPracticeView {

    /// Scroll-mode tap and Tap-mode scrub: move the playhead to a song fraction.
    private func seekToFraction(_ fraction: Double) {
        engine.seek(toSeconds: fraction * duration)
    }

    /// Tap a marker in the list: seek the playhead to it.
    private func seekToMarker(_ marker: WaveformMock.Marker) {
        engine.seek(toSeconds: marker.seconds)
        haptic(.light)
    }

    /// Scroll-mode hold: drop a marker at the held fraction, then open it to name.
    private func dropMarker(_ fraction: Double) {
        let marker = WaveformMock.Marker(seconds: fraction * duration, label: "Marker")
        markers.append(marker)
        markers.sort { $0.seconds < $1.seconds }
        editingMarker = marker
    }

    /// Tap mode = punch in / out at the **current playhead** (taps never move it —
    /// only drag scrubs). First punch: mark the start and play on from where the
    /// playhead already is, the region filling green as it goes. Second punch:
    /// stop and open the confirm pill (bounds ordered + min-width by the helper).
    private func tapPunch() {
        if let start = pendingStart {
            let bounds = WaveformGesture.loopBounds(start, playheadFraction)
            engine.pause()
            pendingStart = nil
            haptic(.medium)
            withAnimation(.easeOut(duration: 0.28)) {
                capture = CaptureDraft(start: bounds.start, end: bounds.end,
                                       fromFine: false, editingLoopID: nil)
            }
        } else {
            pendingStart = playheadFraction
            engine.play()
        }
    }

    /// Fine mode: drag a blue handle, keeping the bounds ordered and at least the
    /// minimum width apart. Preserves whether we're editing an existing loop.
    private func moveFineHandle(_ handle: WaveformGesture.Handle, _ fraction: Double) {
        guard let current = capture else { return }
        let bounds = WaveformGesture.movingHandle(handle, toFraction: fraction,
                                                  start: current.start, end: current.end)
        capture = CaptureDraft(start: bounds.start, end: bounds.end,
                               fromFine: true, editingLoopID: current.editingLoopID)
    }

    /// Entering Fine seeds a selection (the active loop, else a span at the
    /// playhead) and opens the confirm bar; leaving Fine drops an unsaved one.
    /// Any mode switch also clears a half-finished Tap capture + its preview.
    private func modeChanged(to newMode: InteractionMode) {
        if pendingStart != nil {
            pendingStart = nil
            engine.pause()
        }
        switch newMode {
        case .fine:
            if capture?.fromFine != true {
                let seed = activeLoop.map { ($0.start, $0.end) } ?? defaultSelection()
                withAnimation(.easeOut(duration: 0.28)) {
                    capture = CaptureDraft(start: seed.0, end: seed.1, fromFine: true, editingLoopID: nil)
                }
            }
        case .scroll, .tap:
            if capture?.fromFine == true {
                withAnimation(.easeOut(duration: 0.2)) { capture = nil }
            }
        }
    }

    /// Quick-capture a loop around the playhead (transport **+** button). Gesture
    /// capture (Tap/Fine) is primary; this is a one-tap, VoiceOver-friendly path.
    private func quickCapture() {
        guard capture == nil else { return }
        let (start, end) = defaultSelection()
        withAnimation(.easeOut(duration: 0.28)) {
            capture = CaptureDraft(start: start, end: end, fromFine: false, editingLoopID: nil)
        }
    }

    /// Confirm ✓ — write back an existing loop's range, or open naming. The
    /// capture is kept open while naming so a discarded name can restore it
    /// (the pill hides because `namingDraft` is set).
    private func confirmCapture() {
        guard let draft = capture else { return }
        if let id = draft.editingLoopID {
            if let index = loops.firstIndex(where: { $0.id == id }) {
                loops[index].start = draft.start
                loops[index].end = draft.end
            }
            activeLoopID = id
            haptic(.medium)
            finishCapture()
        } else {
            namingDraft = NamingDraft(start: draft.start, end: draft.end)
        }
    }

    /// Confirm ✗ — discard the capture outright (and leave Fine).
    private func cancelCapture() { finishCapture() }

    /// Clear the capture and leave Fine for the default Scroll mode.
    private func finishCapture() {
        withAnimation(.easeOut(duration: 0.2)) {
            capture = nil
            if mode == .fine { mode = .scroll }
        }
    }

    /// The naming sheet was dismissed. A Save already consumed `capture`; if it
    /// survived, this was a Discard — keep a **Fine** selection in place (its
    /// confirm pill reappears so it can be re-adjusted), but drop a Tap capture.
    private func namingDismissed() {
        guard let draft = capture, !draft.fromFine else { return }
        withAnimation(.easeOut(duration: 0.2)) { capture = nil }
    }

    /// Naming-sheet Save — create the loop (empty name → the range), consume the
    /// kept capture, and leave Fine.
    private func saveNamed(_ name: String) {
        guard let draft = namingDraft else { return }
        let range = rangeString(draft.start, draft.end)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let loop = WaveformMock.Loop(name: trimmed.isEmpty ? range : trimmed,
                                     start: draft.start, end: draft.end,
                                     speed: speed, repeats: 4, duration: duration)
        loops.append(loop)
        activeLoopID = loop.id
        capture = nil
        namingDraft = nil
        if mode == .fine { mode = .scroll }
    }

    /// "Adjust range" from a loop's edit sheet → Fine mode seeded with its bounds.
    private func startRangeEdit(_ loop: WaveformMock.Loop) {
        capture = CaptureDraft(start: loop.start, end: loop.end, fromFine: true, editingLoopID: loop.id)
        withAnimation(.easeOut(duration: 0.2)) { mode = .fine }
    }

    private func rangeString(_ start: Double, _ end: Double) -> String {
        "\(timecode(duration * start))–\(timecode(duration * end))"
    }

    /// A default loop span at the playhead, clamped so it never spills off the end.
    private func defaultSelection() -> (Double, Double) {
        let start = min(playheadFraction, 0.85)
        return (start, min(start + 0.12, 0.98))
    }

    /// Entry point for setting an unknown tempo. The tap-tempo / manual-entry
    /// flow is a follow-up commit; for now this is the affordance only.
    private func setBPM() {
        // TODO: present tap-tempo / manual BPM entry (see ADR 0004).
    }

    /// Tapping a loop row: jump to its start and play; if it's already the
    /// active, playing loop, pause. (Region looping arrives on a later branch.)
    private func activate(_ loop: WaveformMock.Loop) {
        if activeLoopID == loop.id && engine.isPlaying {
            engine.pause()
        } else {
            activeLoopID = loop.id
            engine.seek(toSeconds: loop.startSeconds)
            engine.play()
        }
    }

    private func updateLoop(_ loop: WaveformMock.Loop) {
        guard let index = loops.firstIndex(where: { $0.id == loop.id }) else { return }
        loops[index] = loop
    }

    private func deleteLoop(_ loop: WaveformMock.Loop) {
        loops.removeAll { $0.id == loop.id }
        if activeLoopID == loop.id { activeLoopID = loops.first?.id }
    }

    private func updateMarker(_ marker: WaveformMock.Marker) {
        guard let index = markers.firstIndex(where: { $0.id == marker.id }) else { return }
        markers[index] = marker
    }

    private func deleteMarker(_ marker: WaveformMock.Marker) {
        markers.removeAll { $0.id == marker.id }
    }
}

#Preview {
    WaveformPracticeView()
}
