import Foundation
import SwiftData

/// What a take is being recorded against — routes the owner onto a new `Recording` (ADR 0069 §5).
/// A small closed enum so a call site passes `.loop(loop)` and the `Recording`'s polymorphic owner
/// is set correctly without the view touching the relationship fields.
enum RecordingOwner {
    case loop(Loop)
    case exercise(Exercise)
    case song(Song)

    /// Set the matching owner relationship on `recording` (exactly one, per ADR 0058), and snapshot
    /// the owner's caption beside it (ADR 0151) so the take stays identifiable if the owner is later
    /// deleted — the relationship nullifies, the label doesn't. One choke point for both, so a take
    /// can never acquire an owner without acquiring the caption that outlives it.
    func attach(to recording: Recording) {
        switch self {
        case .loop(let loop): recording.loop = loop
        case .exercise(let exercise): recording.exercise = exercise
        case .song(let song): recording.song = song
        }
        recording.ownerLabelAtTake = JournalTimeline.ownerLabel(
            loop: recording.loop, exercise: recording.exercise, song: recording.song)
    }

    /// This owner's takes, newest-first — what the Takes list surfaces (ADR 0069 slice 3). Reading
    /// through the model tracks the SwiftData relationship, so the list refreshes on add/delete.
    var recordingsByRecent: [Recording] {
        switch self {
        case .loop(let loop): loop.recordingsByRecent
        case .exercise(let exercise): exercise.recordingsByRecent
        case .song(let song): song.recordingsByRecent
        }
    }
}

/// Orchestrates one **practice take** over a practice run (ADR 0069): mic permission → arm the
/// record-capable session → capture (`TakeRecorder`) → persist a `Recording` → restore the playback
/// session. Kept separate from the `TakeRecorder` capture primitive and from the run models (which
/// own the playback engine), so a take is a thin, reusable layer on top of whatever is playing.
///
/// **Armed before the run, not toggled mid-play** (device feedback, 2026-07-17): recording is a
/// pre-start toggle. Arming only requests permission and samples the route — it does *not* touch the
/// session. The record-capable session is configured in `beginArmedTake`, called when the run
/// commences (after the count-in) **before** playback starts, so the category flip never happens
/// mid-stream — which was the source of an audible glitch. It also keeps the record decision out of
/// the player's focus during the run. The recorder captures the mic while the run's engine keeps
/// playing out; the two never share a node, so the app never renders its own playback into the file.
@MainActor
@Observable
final class RecordingController {

    /// `idle` → nothing; `armed` → will record when the run starts; `recording` → capturing now.
    enum State: Equatable { case idle, armed, recording }

    private(set) var state: State = .idle

    /// The isolation verdict, sampled on arm (so the setup screen can nudge toward headphones *before*
    /// the run) and re-sampled when the take begins — drives the clean-vs-bleed cue (ADR 0069 §2).
    private(set) var route: RecordingRoute = .cleanIsolated

    /// Set when mic permission was denied, so the UI can point at Settings instead of silently doing
    /// nothing.
    private(set) var micDenied = false

    /// A take that was just **kept**, for the surface's confirmation line. Set only on the keep
    /// branch of `stopRecording`, so a discarded short take can never claim to have been saved.
    /// The *display window* belongs to the view (`TakeSavedNote`), which clears it — the player
    /// assumed takes were being discarded partly because nothing ever said otherwise.
    struct SavedTake: Equatable { let uid: UUID; let duration: TimeInterval }
    private(set) var lastSaved: SavedTake?

    /// Dismiss the "take saved" confirmation once its moment has passed.
    func clearSavedNote() { lastSaved = nil }

    /// True while a screen is holding the record-capable session open across takes (see
    /// `holdRecordSession()`). While held, `stopRecording` leaves the category alone — the screen
    /// owns the two flips instead. It is **not** consulted when *arming*: see `beginArmedTake`.
    private(set) var holdsSession = false

    /// Takes shorter than this are treated as an accidental run — discarded, file and all.
    static let minTakeDuration: TimeInterval = 0.5

    /// Whether a take of `duration` is worth keeping. The pure half of the discard rule, split out
    /// because this is the exact line that deleted real playing when `TakeRecorder` was reporting a
    /// duration of `0` for a take the system had stopped (device pass 2026-08-05). The fix is that
    /// the duration is now honest; this policy is unchanged, and now pinned by a test.
    static func keepsTake(duration: TimeInterval) -> Bool { duration >= minTakeDuration }

    /// This controller's two **independent** claims on the shared audio session (the `AudioPlumbing`
    /// lease): one for the duration of a take, one for the duration of a held record session.
    ///
    /// **Invariant.** A controller contributes exactly
    /// `(state == .recording ? 1 : 0) + (holdsSession ? 1 : 0)` holders at every quiescent point.
    /// Nothing is held while merely `.armed` — arming touches no session, so it must own none.
    ///
    /// Claims rather than raw `retainSession`/`releaseSession` because every seam here can fire twice
    /// or return early — `.onDisappear` runs on every exit, `finishIfRecording` is deliberately
    /// idempotent, and `beginArmedTake` has a failure path. The claim's own flag makes the balance
    /// structural instead of a rule five call sites have to remember.
    ///
    /// Why it matters: without a lease the recorder was not a producer, so the *last* other producer
    /// stopping (a click silenced mid-take, a backing track stopped) deactivated the session under a
    /// live `AVAudioRecorder`, and the take was destroyed.
    ///
    /// **Known residual:** a screen torn down while `.recording` without `.onDisappear` (process
    /// death) leaks a holder. There is no clean fix — `deinit` is `nonisolated` under Swift 6 and
    /// `MainActor.assumeIsolated` there is unsound. `PracticeAudioEngine` has identical exposure.
    private var takeClaim = AudioSessionClaim()
    private var holdClaim = AudioSessionClaim()

    private let recorder = TakeRecorder()
    private var pending: (uid: UUID, fileName: String)?

    /// Invalidation counter for a suspended `toggleTake`. Tapping Record and leaving during the
    /// permission `await` (a routine's auto-advance can do exactly this) would otherwise resume on a
    /// dead screen — starting a hot mic and leaking a lease nothing will release.
    private var epoch = 0

    var isArmed: Bool { state == .armed }
    var isRecording: Bool { state == .recording }

    /// Live seconds captured, for the on-screen timer.
    var elapsed: TimeInterval { recorder.elapsed }

    /// Toggle the pre-start arm. Turning it on requests mic permission on first use (the system prompt
    /// happens here, on the setup screen — not during the run) and samples the current route; a denial
    /// leaves it off and sets `micDenied`. Turning it off just clears the flag. No-op while recording.
    func toggleArm() async {
        switch state {
        case .recording: return
        case .armed: state = .idle
        case .idle:
            let wasUndetermined = MicPermission.status == .undetermined
            guard await MicPermission.request() else {
                if wasUndetermined { Analytics.send(.micPermission(outcome: .denied)) }
                micDenied = true
                return
            }
            if wasUndetermined { Analytics.send(.micPermission(outcome: .granted)) }
            Analytics.send(.toolOpened(tool: .recording))
            micDenied = false
            route = RecordingRoute.current()
            state = .armed
        }
    }

    /// Arm **without prompting** — for a routine block marked to record when the routine was authored
    /// (ADR 0179). The two-step arm grammar is unchanged; what changes is who taps it. `toggleArm()`
    /// is `async` only because it may raise the system permission prompt, and a routine block cannot
    /// wait on one: with auto-start on, the block is already running by the time a prompt would be
    /// answered. Permission was settled at authoring time, which is the settled, non-playing moment
    /// ADR 0069 slice 2 wanted the prompt to happen in anyway.
    ///
    /// Revoked since? The block runs normally and records nothing, with `micDenied` set so the screen
    /// can say why — never a hang, and never a silent failure. Arming touches no session, so this
    /// takes no lease: the invariant on `takeClaim`/`holdClaim` holds unchanged.
    func armIfPermitted() {
        guard state == .idle else { return }
        switch MicPermission.status {
        case .granted:
            micDenied = false
            route = RecordingRoute.current()
            state = .armed
        case .denied:
            micDenied = true
        case .undetermined:
            // Deliberately nothing. Prompting here is the one thing this method exists not to do.
            break
        }
    }

    /// Begin the take if armed — called as the run starts, **before** playback, so the session flips
    /// to `.playAndRecord` with no audio in flight (no mid-play glitch). Re-samples the route (the user
    /// may have plugged in headphones since arming). No permission prompt here; that happened on arm.
    func beginArmedTake() {
        guard state == .armed else { return }
        // Lease first: the guard above is the only way out before this point, so every path from here
        // pairs with exactly one release.
        takeClaim.take()
        // **Assert** the record category rather than trusting `holdsSession`. A held session can be
        // silently downgraded by anything that asserts `.playback` — the Takes sheet's
        // `RecordingPlayer` did exactly that, so a take recorded after auditioning one was captured
        // under `.playback` and lost. `ensureRecordSession` is a no-op when the category is already
        // right, so the hold's promise — never a flip with audio in flight — is kept.
        AudioPlumbing.ensureRecordSession(label: "take")
        route = RecordingRoute.current()

        let uid = UUID()
        let fileName = RecordingStore.fileName(for: uid)
        guard let url = try? RecordingStore.url(for: fileName), recorder.start(to: url) else {
            // Failed to arm — restore playback, unless the screen is holding the session itself.
            // Restore *before* giving the lease back, so the "last one out" deactivation lands with
            // nothing sounding rather than immediately after a re-activation.
            if !holdsSession { AudioPlumbing.configurePlaybackSession(label: "take") }
            takeClaim.give(label: "take")
            state = .idle
            return
        }
        pending = (uid, fileName)
        state = .recording
    }

    /// Stop the take, persist it against `owner` (unless it was too short — then discard the file), and
    /// restore the playback session so the metronome/playback path is unaffected once nothing is armed
    /// (ADR 0069 §3). Returns to `idle` — a new run must re-arm.
    func stopRecording(owner: RecordingOwner, context: ModelContext) {
        // Structured so the lease is released on **every** exit from `.recording`, not only the
        // branch where `pending` happens to be non-nil.
        guard state == .recording else { return }
        let duration = recorder.stop()
        state = .idle
        let finished = pending
        pending = nil

        if let finished {
            if Self.keepsTake(duration: duration) {
                let take = Recording(fileName: finished.fileName, duration: duration, uid: finished.uid)
                owner.attach(to: take)
                context.insert(take)
                try? context.save()
                lastSaved = SavedTake(uid: finished.uid, duration: duration)
            } else {
                // The one place a take's audio is destroyed. Logged because when this fires for a take
                // the player actually made, something stopped the recorder behind our back — the
                // failure that cost real playing before `TakeRecorder` learned to read the file back.
                AudioPlumbing.log.error(
                    "take: discarded a \(duration, format: .fixed(precision: 2))s take as too short")
                try? RecordingStore.delete(fileName: finished.fileName)
            }
        }
        if !holdsSession { AudioPlumbing.configurePlaybackSession(label: "take") }
        takeClaim.give(label: "take")   // last: the restore above must happen on a live session
    }

    /// Finalize any in-flight take on run stop / screen exit, so a take is never left recording after
    /// the audio it was played over has stopped. Idempotent.
    func finishIfRecording(owner: RecordingOwner, context: ModelContext) {
        guard state == .recording else { return }
        stopRecording(owner: owner, context: context)
    }

    // MARK: - Start-less surfaces (ADR 0069 amendment, 2026-08-05)

    /// Start or end a take on a surface with no Start to arm against — a freeform block, whose clock
    /// runs from arrival (ADR 0136 F4). Composed so the two-step never leaks into the view and
    /// `micDenied` stays handled in one place: idle prompts for permission, samples the route, and
    /// begins; recording stops and persists. A denial leaves the state idle with `micDenied` set.
    func toggleTake(owner: RecordingOwner, context: ModelContext) async {
        switch state {
        case .recording:
            stopRecording(owner: owner, context: context)
        case .idle:
            // The permission prompt suspends this call. A routine's auto-advance timer can tear the
            // screen down while we're suspended, so the epoch is checked on resume: without it the
            // continuation starts a recorder on a dead screen and nothing is left to stop it.
            let token = epoch
            await toggleArm()
            guard token == epoch, state == .armed else { return }   // left, denied, or dismissed
            beginArmedTake()
        case .armed:
            beginArmedTake()
        }
    }

    /// Hold the record-capable session open for the lifetime of a screen that already has audio in
    /// flight and no Start to arm against. The category flip is the source of the audible glitch ADR
    /// 0069 slice 2 designed the arm grammar around; a mid-session toggle would otherwise flip it
    /// *twice* under a running click. Called on appearance, before the click starts, so the flip
    /// happens with nothing sounding — and the take toggle then changes no category at all.
    ///
    /// Local to the screen that calls it: ADR 0069 §3's "never a global flip" is unaffected, because
    /// `releaseRecordSession()` restores playback on the way out.
    func holdRecordSession() {
        guard !holdsSession else { return }
        holdClaim.take()
        AudioPlumbing.configureRecordSession(label: "take")
        holdsSession = true
    }

    /// Release a held session and restore playback — the exit half of `holdRecordSession()`. Call it
    /// *after* finalizing any in-flight take, so the file is closed while the session can still
    /// record. Idempotent.
    func releaseRecordSession() {
        // Invalidate any suspended arm on the way out — the screen that started it is going away.
        epoch &+= 1
        guard holdsSession else { return }
        holdsSession = false
        AudioPlumbing.configurePlaybackSession(label: "take")
        holdClaim.give(label: "take")
    }
}
