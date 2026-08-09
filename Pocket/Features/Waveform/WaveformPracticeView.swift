import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The core practice screen (design brief §4.1): a fixed practice cockpit over a
/// scrollable reference area, driven (for now) by mock song data plus a generated
/// dev audio sample. Real playback runs through `PracticeAudioEngine`; the three
/// transport modes are live as a gesture engine (Scroll/Tap/Fine — ADRs 0003,
/// 0005). Loop capture is a keyboard-free confirm step then a naming sheet.
///
/// State + handlers live in `WaveformPracticeModel` (ADR 0007); this view is the
/// thin body that observes and binds to it. Sections live in
/// `WaveformSections.swift`; shared chrome in `WaveformChrome.swift`.
struct WaveformPracticeView: View {

    @State private var model: WaveformPracticeModel
    // Landscape on iPhone reports a compact vertical size class — the signal the practice
    // screen uses to switch to its side-rail layout (ADR 0042).
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    // Landscape only: the loops/markers reference is a slide-in drawer (ADR 0042), closed by
    // default so the waveform owns the full width; the top-bar menu button toggles it.
    @State private var drawerOpen = false
    // Relink (ADR 0148 §6) — repairing a song whose audio can't be found, without leaving the
    // screen the player came here to use.
    @State private var relinking = false
    @State private var relinkAlert: RelinkAlert?

    init(song: Song, context: ModelContext) {
        _model = State(initialValue: WaveformPracticeModel(song: song, context: context))
    }

    private var isLandscape: Bool { verticalSizeClass == .compact }

    /// A one-shot message about a relink — the failure, or the success that needs a caveat.
    struct RelinkAlert {
        let title: String
        let message: String
    }

    /// Bool-bound like `LibraryView`'s import error, so the alert clears itself on dismiss.
    private var relinkAlertBinding: Binding<Bool> {
        Binding(get: { relinkAlert != nil }, set: { if !$0 { relinkAlert = nil } })
    }

    /// Repair this song's audio from a file the player picks (ADR 0148 §6). On success the screen
    /// simply starts working — no confirmation for the ordinary case, because the waveform
    /// redrawing and the transport coming alive *is* the confirmation.
    private func handleRelink(_ result: Result<[URL], Error>) {
        // Belt to the overlay's braces: a second pick landing mid-relink would race two decodes
        // onto the same `sourceID`, and the loser would overwrite the winner's copy.
        guard !model.isLoadingAudio else { return }
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result {
                relinkAlert = RelinkAlert(title: "Couldn’t open that file",
                                          message: error.localizedDescription)
            }
            return
        }
        Task {
            do {
                let outcome = try await model.relinkAudio(to: url)
                // A different *length* means a different recording, not a re-encode — and the
                // loops were drawn against the old one. Say so rather than letting the player
                // discover it as loops that play the wrong bars, but never delete their work
                // on the strength of a guess.
                if outcome.durationChangedMaterially {
                    relinkAlert = RelinkAlert(
                        title: "Song relinked",
                        message: "That file is a different length from the original, so this "
                            + "song's loops and markers may no longer line up. Nothing was "
                            + "deleted — you can adjust or remove them yourself.")
                }
            } catch {
                relinkAlert = RelinkAlert(title: "Couldn’t use that file",
                                          message: error.localizedDescription)
            }
        }
    }

    var body: some View {
        @Bindable var model = model
        ZStack {
            PocketColor.background.ignoresSafeArea()

            if isLandscape {
                landscapeLayout(model: model)
            } else {
                portraitLayout(model: model)
            }

            // Dim + spinner while the audio opens, so a slow file read reads as
            // "loading" rather than "frozen" (and blocks taps on half-ready controls).
            if model.isLoadingAudio {
                AudioLoadingOverlay()
                    .transition(.opacity)
            }

            // Honest failure state: the bookmark no longer resolves or the file
            // won't read — say so instead of presenting a dead transport, and hand
            // back a way off the screen rather than leaving the back chevron as the
            // only exit.
            if model.audioLoadFailed {
                AudioUnavailableNotice(onRelink: { relinking = true }, onLeave: { dismiss() })
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.isLoadingAudio)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.audioLoadFailed)
        // Single selection: relink repairs *this* song, unlike the library's multi-select import.
        .fileImporter(isPresented: $relinking, allowedContentTypes: [.audio],
                      allowsMultipleSelection: false, onCompletion: handleRelink)
        .alert(relinkAlert?.title ?? "", isPresented: relinkAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(relinkAlert?.message ?? "")
        }
        // Both orientations draw their own compact back button (portrait: inline with the
        // song strip; landscape: the back · title · menu bar), so the system nav bar is
        // hidden throughout — in portrait it otherwise reserved a tall empty band above the
        // song strip (no title set → wasted space). Hiding it lets the header rise to just
        // under the status bar (P1a; ADR 0042).
        .toolbar(.hidden, for: .navigationBar)
        // Practice is the one screen that rotates (ADR 0042): more width = sharper
        // waveform + more precise A/B drag. Reverts to portrait-only on exit.
        .landscapeEnabled()
        .keepAwakeDuringPractice()   // Settings V1 (ADR 0050)
        // Don't carry an open drawer across a rotation back to portrait.
        .onChange(of: isLandscape) { _, landscape in if !landscape { drawerOpen = false } }
        // Stop a playhead scrub near the left edge from popping back to the library
        // (ADR 0030): suppress the interactive swipe-back while a finger is on the waveform.
        .background(SwipeBackGuard(disabled: model.isScrubbing))
        .overlay(alignment: .bottom) {
            if let toast = model.undoToast {
                UndoToastView(message: toast.message, onUndo: model.performUndo)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $model.editingLoop, onDismiss: model.launchPendingPractice) { ref in
            let loop = ref.value
            LoopEditSheet(loop: loop,
                          autoColor: LoopColor.derivedColor(for: loop, among: model.loops),
                          onDelete: { model.deleteLoop(loop) },
                          onAdjustRange: { model.startRangeEdit(loop) },
                          onSaved: { restore in model.presentUndo("Saved changes", undo: restore) },
                          onPracticeNow: { model.pendingPracticeLoop = loop },
                          onOpenNestedAudio: model.pauseForNestedAudio)
        }
        .fullScreenCover(item: $model.practiceLoop) { loop in
            // "Practice now" from the edit sheet (ADR 0082): the loop trainer full-screen. The back
            // control returns to the waveform it launched from (a cover has no back button of its own;
            // standalone `LoopRunView` leaves the leading slot empty, so there's no conflict).
            NavigationStack {
                LoopRunView(loop: loop)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { model.practiceLoop = nil } label: {
                                Image(systemName: "chevron.backward")
                            }
                            .accessibilityLabel("Back to waveform")
                        }
                    }
            }
        }
        .sheet(item: $model.editingMarker) { ref in
            let marker = ref.value
            MarkerEditSheet(marker: marker, onDelete: { model.deleteMarker(marker) })
        }
        .sheet(item: $model.editingAutomatorLoop) { ref in
            let loop = ref.value
            AutomatorSheet(loop: loop, song: model.song,
                           onSet: { model.startAutomator(for: loop) },
                           onTurnOff: { model.turnOffAutomator(for: loop) })
        }
        .sheet(isPresented: $model.showingSongDetails) {
            // Routed through the model rather than `SongRelinker` directly (ADR 0152): the engine
            // has this song's file open, and `SongFileStore.adopt` replaces those bytes in place.
            // `relinkAudio` stops the engine and reloads around the swap; the plain path would
            // leave a live `AVAudioFile` reading a file that no longer exists.
            SongDetailsSheet(song: model.song,
                             replaceAudio: { try await model.relinkAudio(to: $0) })
        }
        // Bulk practice categories across the selected loops (ADR 0125), from the selection
        // header's slider button — the chevron's old slot.
        .sheet(isPresented: $model.showingLoopBulkEdit) {
            LoopBulkEditSheet(loops: model.selectedLoops, onApply: model.applyBulkEdit)
        }
        .sheet(isPresented: $model.settingBPM) {
            BPMSheet(engine: model.engine, currentBPM: model.song.tempoBPM,
                     currentDownbeat: model.song.downbeatSeconds,
                     currentBeatsPerBar: model.song.beatsPerBar,
                     currentNoteValue: model.song.noteValue,
                     onCommit: { bpm, downbeat, beats, note in
                         model.commitTempo(bpm: bpm, downbeat: downbeat,
                                           beatsPerBar: beats, noteValue: note)
                     },
                     onSetOnWaveform: { bpm in
                         model.commitTempo(bpm: bpm, downbeat: nil)
                         model.beginSetDownbeat(resumeSheet: true)
                     },
                     onEstimate: {
                         await model.estimateTempoFromAudio().map { ($0.bpm, $0.downbeatSeconds) }
                     })
        }
        .task { await model.loadAudio(); model.beginPlaybackSession() }
        // Stop-on-exit (ADR 0025): halt playback and remove the lock-screen command
        // targets when leaving the screen, so audio stops and nothing keeps the
        // engine alive via the global command center.
        .onDisappear { model.endPlaybackSession() }
        // Page-mode (ADR 0010): as the playhead advances, hold the window still until
        // it sweeps to ~90%, then page forward. Only re-anchors at page edges. Also
        // refresh the lock-screen clock (throttled) so a seek shows up there.
        .onChange(of: model.playheadFraction) { _, _ in
            model.advancePageIfNeeded()
            model.refreshNowPlaying()
        }
        // Crisp deep-zoom (ADR 0020): re-downsample the visible window when the
        // viewport changes. `viewport` is derived purely from these two, both Equatable.
        .onChange(of: model.zoomSpan) { _, _ in model.scheduleDetailRefresh() }
        .onChange(of: model.viewportStart) { _, _ in model.scheduleDetailRefresh() }
        .onChange(of: model.speed) { _, newValue in
            model.engine.setRate(newValue)
            model.refreshNowPlaying(force: true)   // rate change re-anchors the lock-screen clock
        }
        // Per-loop automator: step the speed as the active loop wraps, and snap to the
        // ramp's current step when playback (re)starts (ADR 0013).
        .onChange(of: model.engine.loopIteration) { _, iteration in
            model.automatorAdvance(toLoopIteration: iteration)
        }
        .onChange(of: model.engine.isPlaying) { _, playing in
            if playing { model.automatorAdvance(toLoopIteration: model.engine.loopIteration) }
            model.refreshNowPlaying(force: true)   // play/pause flips the lock-screen control + clock
        }
    }

    // MARK: - Layouts (ADR 0042)

    /// Portrait: the cockpit (headed by the song strip) stacked over the loops/markers
    /// reference list, split by a hairline.
    private func portraitLayout(model: WaveformPracticeModel) -> some View {
        VStack(spacing: 0) {
            PracticeCockpit(model: model) {
                // Compact back button inline to the left of the song strip — the system nav
                // bar is hidden (it reserved a tall empty band above the header), so this
                // lets the title sit just under the status bar.
                HStack(alignment: .top, spacing: 12) {
                    backButton
                    SongStrip(song: model.song, onHoldTitle: { model.showingSongDetails = true })
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 12)
            Rectangle()
                .fill(PocketColor.surfaceSubtle)
                .frame(height: 1)
            PracticeReference(model: model)
        }
    }

    /// Landscape: the waveform cockpit owns the full width (headed by a compact back · title ·
    /// menu bar); the loops/markers reference slides in as a right-edge drawer, toggled by the
    /// menu button and closed by default so the waveform keeps the width until you need it.
    private func landscapeLayout(model: WaveformPracticeModel) -> some View {
        ZStack(alignment: .topTrailing) {
            PracticeCockpit(model: model, landscape: true) {
                landscapeTopBar(model: model)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)

            if drawerOpen {
                // Scrim — tap outside the drawer to dismiss it.
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { drawerOpen = false }
                    .transition(.opacity)
                PracticeReference(model: model, compact: true)
                    .frame(width: 320)
                    .frame(maxHeight: .infinity)
                    .background(PocketColor.background)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(PocketColor.surfaceSubtle).frame(width: 1)
                    }
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: drawerOpen)
    }

    /// The compact circular back chevron used by both orientations now that the system nav
    /// bar is hidden (portrait draws it inline with the song strip, landscape in its top bar).
    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.futura(size: 16, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(PocketColor.surfaceStandard))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to library")
    }

    /// Landscape top bar: a compact back chevron, the song title/artist (hold for details,
    /// like the portrait strip), and the menu button that toggles the loops/markers drawer.
    private func landscapeTopBar(model: WaveformPracticeModel) -> some View {
        HStack(spacing: 14) {
            backButton

            VStack(alignment: .leading, spacing: 1) {
                Text(model.song.title)
                    .font(.futura(.headline))
                    .foregroundStyle(PocketColor.textPrimary)
                    .lineLimit(1)
                Text(model.song.artist)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.4) {
                haptic(.medium)
                model.showingSongDetails = true
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint("Hold to view song details")
            .accessibilityAction(named: "Song details") { model.showingSongDetails = true }

            Spacer(minLength: 8)

            Button { drawerOpen.toggle() } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.futura(size: 17, weight: .semibold))
                    .foregroundStyle(drawerOpen ? PocketColor.background : PocketColor.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(drawerOpen ? PocketColor.textPrimary : PocketColor.surfaceStandard))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Loops and markers")
            .accessibilityValue(drawerOpen ? "Open" : "Closed")
        }
    }
}

#Preview {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    let song = Song.sample()
    container.mainContext.insert(song)
    return WaveformPracticeView(song: song, context: container.mainContext)
        .modelContainer(container)
}
