import SwiftData
import SwiftUI

/// A **song-block play-along** (ADR 0066 / 0071): the compact, audio-only run screen for a `Song`
/// block in a routine — the repertoire counterpart of `ExerciseRunView` / `LoopRunView`. A song block
/// is an open jam, so this is deliberately minimal (ADR 0070 — no evaluation surface): one **fixed
/// play-along speed** you set (no ramp), play / pause, and **−10s / +10s** seeks over the live
/// position. By default the song **loops** until you tap **Done**, which logs the play-along and moves
/// on (ADR 0266); with *Loop song blocks* off it plays through once and auto-advances. Skip still
/// moves on without logging anything, as it does for every block.
///
/// It owns a `SongPlayAlongModel` (and through it a private `PracticeAudioEngine`), so it's
/// independent of the waveform screen. As with the loop run, a routine block gets the routine chrome
/// (progress strip, Skip, exit) and a **visual count-in** before playback; standalone (`nil` context)
/// it's just the play-along.
struct SongPlayAlongView: View {
    let song: Song
    /// Routine-session chrome (progress, Skip, auto-advance) when a block in a routine; `nil` standalone.
    var routineContext: RoutineRunContext?
    @State private var model: SongPlayAlongModel
    @Environment(\.modelContext) private var modelContext

    /// Whether the routine count-in overlay is showing (routine mode only) — gates playback start.
    @State private var showCountIn = false
    @State private var wired = false
    /// When the current play-through started, or `nil` when nothing is playing — the practice log's
    /// clock (ADR 0117). Consumed by the natural-completion hook, so a play-along stopped by hand logs
    /// nothing, exactly as a hand-stopped ramp does.
    @State private var runStartedAt: Date?

    init(song: Song, routineContext: RoutineRunContext? = nil) {
        self.song = song
        self.routineContext = routineContext
        _model = State(initialValue: SongPlayAlongModel(song: song))
    }

    private var isRunning: Bool { model.isRunning }
    private var title: String { song.title.isEmpty ? "Song" : song.title }
    private var fraction: Double {
        model.duration > 0 ? min(1, max(0, model.currentTime / model.duration)) : 0
    }

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 8)
            hero
            tempoControl
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .routineSessionChrome(routineContext)
        .toolbar { doneButton }
        .safeAreaInset(edge: .bottom) { transport }
        .overlay { if showCountIn { RoutineCountInOverlay(onComplete: countInFinished) } }
        .keepAwakeDuringPractice()   // Settings V1 (ADR 0050)
        .onAppear(perform: wireIfNeeded)
        .task { await model.loadIfNeeded(); maybeAutoStart() }
        .onDisappear { model.stop() }
    }

    // MARK: - Hero

    /// The playhead + a slim progress bar while running; the fixed play-along speed while stopped.
    @ViewBuilder
    private var hero: some View {
        if isRunning {
            VStack(spacing: 14) {
                Text("\(timecode(model.currentTime)) / \(timecode(model.duration))")
                    .font(.pocketMono(.largeTitle))
                    .foregroundStyle(PocketColor.textPrimary)
                    .contentTransition(.numericText())
                progressBar
                Text("\(model.percent)% of original tempo")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Playing along at \(model.percent) percent of original tempo")
        } else {
            VStack(spacing: 6) {
                Text("\(model.percent)%")
                    .font(.pocketMono(.largeTitle))
                    .foregroundStyle(PocketColor.textPrimary)
                    .contentTransition(.numericText())
                Text("of original tempo")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                Text(AppSettings.routineSongLoop
                     ? "Plays as a loop — tap Done when you've finished"
                     : "Plays through once, then moves on")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(PocketColor.textSecondary.opacity(0.2))
                Capsule().fill(PocketColor.practice).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    // MARK: - Tempo (fixed, live-adjustable — no ramp)

    private var tempoControl: some View {
        HStack(spacing: 18) {
            StepperButton(symbol: "minus", label: "Slower", tint: PocketColor.practice) {
                model.setPercent(model.percent - 1)
            }
            VStack(spacing: 2) {
                Text("Play-along speed")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                Text("\(model.percent)%")
                    .font(.pocketMono(.title3))
                    .foregroundStyle(PocketColor.textPrimary)
                    .contentTransition(.numericText())
            }
            .frame(minWidth: 120)
            StepperButton(symbol: "plus", label: "Faster", tint: PocketColor.practice) {
                model.setPercent(model.percent + 1)
            }
        }
    }

    // MARK: - Transport

    private var transport: some View {
        Group {
            if isRunning {
                HStack(spacing: 14) {
                    seekButton(symbol: "gobackward.10", label: "Back 10 seconds", seconds: -10)
                    Button { model.toggle(); haptic(.medium) } label: {
                        Label(model.transport == .playing ? "Pause" : "Resume",
                              systemImage: model.transport == .playing ? "pause.fill" : "play.fill")
                            .pocketRunButton
                    }
                    .buttonStyle(.plain)
                    seekButton(symbol: "goforward.10", label: "Forward 10 seconds", seconds: 10)
                }
            } else {
                VStack(spacing: 8) {
                    if model.loadFailed {
                        Text("Couldn't load this song's audio — the file may have moved or been deleted.")
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    Button(action: startTapped) {
                        Label("Play along", systemImage: "play.fill").pocketRunButton
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isLoading || model.loadFailed)
                    .accessibilityLabel("Start playing along")
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 8)
        .background(PocketColor.background.opacity(0.95))
    }

    private func seekButton(symbol: String, label: String, seconds: TimeInterval) -> some View {
        Button { model.skip(by: seconds); haptic(.light) } label: {
            Image(systemName: symbol)
                .font(.futura(.title3))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(width: 56, height: 56)
                .background(Circle().fill(PocketColor.textSecondary.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Start

    /// Wire the natural-completion hook once (routine mode only — a looping song never fires it), and
    /// log the play-through first (ADR 0117), before advancing tears this screen down.
    private func wireIfNeeded() {
        guard !wired else { return }
        if routineContext != nil {
            model.onFinished = { finish() }
        }
        wired = true
    }

    /// Append this play-through to the **practice log** (ADR 0117). Playing along with the record is
    /// practice, so it earns its minutes and its day on the calendar; no tempo is recorded, because a
    /// play-along is played at the song's own speed rather than at a tempo you own.
    ///
    /// Two ways in: the song **playing through** with *Loop song blocks* off, and **Done** (ADR 0266).
    /// A looping play-along has no end of its own, so the player saying they're finished *is* its end,
    /// as it is for an improvise block (ADR 0135 B3b). The length is from Play along to Done. Skip and
    /// exit still log nothing.
    ///
    /// `unitUID` is deliberately `nil`: `Song` is the one model with no business `uid` — it is
    /// identified by its `SongRef`. The song travels as `songSourceID` instead (ADR 0241), the same
    /// key the archive already uses for a song, so the Practice log can say which song was played
    /// without a `uid` being added to the store's aggregate root.
    private func logCompletedRun() {
        guard let startedAt = runStartedAt else { return }
        runStartedAt = nil
        PracticeLogWriter.log(kind: .song,
                              startedAt: startedAt,
                              unitUID: nil,
                              routineUID: routineContext?.routineUID,
                              songSourceID: song.sourceID,
                              unitLabel: song.title,
                              into: modelContext)
    }

    /// The one completion seam, shared by Done and the song playing through: log, then advance,
    /// because advancing tears this screen down.
    private func finish() {
        logCompletedRun()
        routineContext?.onFinished()
    }

    /// **Done** — or **Finish** on the last block — as a nav-bar button, the way an improvise or ear
    /// block finishes (ADR 0266). A looping song never ends on its own, and before this the only way
    /// on was ›, which logs nothing: an hour of playing along counted for no minutes.
    ///
    /// Shown only once the play-along has started. Before that there is nothing to finish, and a Done
    /// that only moved on would be a second Skip.
    @ToolbarContentBuilder private var doneButton: some ToolbarContent {
        if let context = routineContext, isRunning {
            ToolbarItem(placement: .topBarTrailing) {
                Button(context.stageIndex >= context.stageCount - 1 ? "Finish" : "Done") {
                    haptic(.light)
                    finish()
                }
                .font(.futura(.body, weight: .semibold))
                .tint(PocketColor.practice)
                .accessibilityLabel("Done with this song")
            }
        }
    }

    /// Start tapped: in a routine, run the visual count-in first (ADR 0071); standalone, start now.
    private func startTapped() {
        if routineContext != nil { showCountIn = true; haptic(.light) } else { commitAndStart() }
    }

    /// Auto-start on arrival when the context asks (Settings-gated; never the first block) and the
    /// audio is ready — routes through the same count-in as a tapped Start.
    private func maybeAutoStart() {
        if routineContext?.autoStart == true, !isRunning, !model.isLoading, !model.loadFailed {
            showCountIn = true
        }
    }

    private func countInFinished() {
        showCountIn = false
        commitAndStart()
    }

    /// Persist the chosen play-along speed on the song (so it resumes here next time, ADR 0044) and
    /// begin playback at that fixed speed, looping per the current setting.
    private func commitAndStart() {
        song.lastPracticedSpeed = SongPlayAlongModel.rate(forPercent: model.percent)
        song.lastPracticed = .now
        try? modelContext.save()
        runStartedAt = .now     // the practice log's clock (ADR 0117)
        model.start(percent: model.percent, loopWholeSong: AppSettings.routineSongLoop)
        haptic(.medium)
    }
}

#Preview("Song play-along") {
    let song = Song(title: "Wish You Were Here", artist: "Pink Floyd",
                    duration: 200, ref: .localFile(bookmark: Data()))
    return NavigationStack { SongPlayAlongView(song: song) }
        .preferredColorScheme(.dark)
}
