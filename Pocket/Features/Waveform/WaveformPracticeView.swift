import SwiftData
import SwiftUI

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

    init(song: Song, context: ModelContext) {
        _model = State(initialValue: WaveformPracticeModel(song: song, context: context))
    }

    private var isLandscape: Bool { verticalSizeClass == .compact }

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
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.isLoadingAudio)
        .preferredColorScheme(.dark)
        // Landscape uses its own compact top bar (back · title · menu), so hide the system
        // nav bar there; portrait keeps it (ADR 0042).
        .toolbar(isLandscape ? .hidden : .automatic, for: .navigationBar)
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
        .sheet(item: $model.editingLoop) { loop in
            LoopEditSheet(loop: loop,
                          autoColor: LoopColor.derivedColor(for: loop, among: model.loops),
                          onDelete: { model.deleteLoop(loop) },
                          onAdjustRange: { model.startRangeEdit(loop) })
        }
        .sheet(item: $model.editingMarker) { marker in
            MarkerEditSheet(marker: marker, onDelete: { model.deleteMarker(marker) })
        }
        .sheet(item: $model.editingAutomatorLoop) { loop in
            AutomatorSheet(loop: loop, song: model.song,
                           onSet: { model.startAutomator(for: loop) },
                           onTurnOff: { model.turnOffAutomator(for: loop) })
        }
        .sheet(item: $model.journalingLoop) { loop in
            LoopJournalSheet(loop: loop,
                             onAdd: { text, kind in model.addJournalEntry(to: loop, text: text, kind: kind) },
                             onUpdate: model.updateJournalEntry,
                             onDelete: model.deleteJournalEntry)
        }
        .sheet(isPresented: $model.showingSongDetails) {
            SongDetailsSheet(song: model.song)
        }
        .sheet(isPresented: $model.settingBPM) {
            BPMSheet(engine: model.engine, currentBPM: model.song.tempoBPM,
                     currentDownbeat: model.song.downbeatSeconds,
                     onCommit: model.commitTempo,
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
                SongStrip(song: model.song, onHoldTitle: { model.showingSongDetails = true })
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Rectangle()
                .fill(Color.white.opacity(0.08))
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
            .padding(.vertical, 8)

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
                        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)
                    }
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: drawerOpen)
    }

    /// Landscape top bar: a compact back chevron, the song title/artist (hold for details,
    /// like the portrait strip), and the menu button that toggles the loops/markers drawer.
    private func landscapeTopBar(model: WaveformPracticeModel) -> some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to library")

            VStack(alignment: .leading, spacing: 1) {
                Text(model.song.title)
                    .font(.headline)
                    .foregroundStyle(PocketColor.textPrimary)
                    .lineLimit(1)
                Text(model.song.artist)
                    .font(.subheadline)
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
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(drawerOpen ? PocketColor.background : PocketColor.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(drawerOpen ? PocketColor.textPrimary : Color.white.opacity(0.10)))
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
