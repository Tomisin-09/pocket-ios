import Foundation
import SwiftData

/// What a take is being recorded against — routes the owner onto a new `Recording` (ADR 0069 §5).
/// A small closed enum so a call site passes `.loop(loop)` and the `Recording`'s polymorphic owner
/// is set correctly without the view touching the relationship fields.
enum RecordingOwner {
    case loop(Loop)
    case exercise(Exercise)
    case song(Song)

    /// Set the matching owner relationship on `recording` (exactly one, per ADR 0058).
    func attach(to recording: Recording) {
        switch self {
        case .loop(let loop): recording.loop = loop
        case .exercise(let exercise): recording.exercise = exercise
        case .song(let song): recording.song = song
        }
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

    /// Takes shorter than this are treated as an accidental run — discarded, file and all.
    static let minTakeDuration: TimeInterval = 0.5

    private let recorder = TakeRecorder()
    private var pending: (uid: UUID, fileName: String)?

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
            guard await MicPermission.request() else {
                micDenied = true
                return
            }
            micDenied = false
            route = RecordingRoute.current()
            state = .armed
        }
    }

    /// Begin the take if armed — called as the run starts, **before** playback, so the session flips
    /// to `.playAndRecord` with no audio in flight (no mid-play glitch). Re-samples the route (the user
    /// may have plugged in headphones since arming). No permission prompt here; that happened on arm.
    func beginArmedTake() {
        guard state == .armed else { return }
        AudioPlumbing.configureRecordSession(label: "take")
        route = RecordingRoute.current()

        let uid = UUID()
        let fileName = RecordingStore.fileName(for: uid)
        guard let url = try? RecordingStore.url(for: fileName), recorder.start(to: url) else {
            AudioPlumbing.configurePlaybackSession(label: "take")   // failed to arm — restore playback
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
        guard state == .recording, let pending else { return }
        let duration = recorder.stop()
        state = .idle
        self.pending = nil

        if duration >= Self.minTakeDuration {
            let take = Recording(fileName: pending.fileName, duration: duration, uid: pending.uid)
            owner.attach(to: take)
            context.insert(take)
            try? context.save()
        } else {
            try? RecordingStore.delete(fileName: pending.fileName)
        }
        AudioPlumbing.configurePlaybackSession(label: "take")
    }

    /// Finalize any in-flight take on run stop / screen exit, so a take is never left recording after
    /// the audio it was played over has stopped. Idempotent.
    func finishIfRecording(owner: RecordingOwner, context: ModelContext) {
        guard state == .recording else { return }
        stopRecording(owner: owner, context: context)
    }
}
