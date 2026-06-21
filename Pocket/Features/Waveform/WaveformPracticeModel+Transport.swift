import SwiftUI

// MARK: - Transport playback controls (ADR 0030)
//
// The rewind · pause · forward cluster in the transport bar. The skip targets
// depend on whether a loop is active:
//   • loop active   — rewind 1× restarts the loop, 2× → previous loop;
//                     forward 1× → next loop. (Ordered by start time.)
//   • no loop       — rewind 1× restarts the song; previous/next *song* is
//                     reserved for cross-song navigation (a later branch) and is
//                     a no-op for now, so those buttons read disabled.
// Pure neighbour-finding lives in `TransportNav`; this file is the engine wiring.

extension WaveformPracticeModel {

    /// The active loop's identity colour for the transport strip, or `nil` when no
    /// loop is active (the strip is absent in that layout).
    var activeLoopColor: Color? {
        activeLoop.map { LoopColor.color(for: $0, among: loops) }
    }

    /// Whether the previous-skip (double-tap rewind) has a target right now.
    var hasPreviousTarget: Bool {
        activeLoop != nil && TransportNav.previous(before: activeLoopID, in: loops.map(\.uid)) != nil
    }

    /// Whether the next-skip (single-tap forward) has a target right now.
    var hasNextTarget: Bool {
        activeLoop != nil && TransportNav.next(after: activeLoopID, in: loops.map(\.uid)) != nil
    }

    /// Rewind, single tap — restart the active loop, or the song from the top when
    /// none is active. Seek only; the play/pause state is left as-is.
    func transportRestart() {
        engine.seek(toSeconds: activeLoop?.startSeconds ?? 0)
        haptic(.light)
    }

    /// Rewind, double tap — jump to the previous loop (by start order). No-op when
    /// there isn't one (or no loop is active — previous *song* lands in a later branch).
    func transportPrevious() {
        guard let uid = TransportNav.previous(before: activeLoopID, in: loops.map(\.uid)),
              let loop = loops.first(where: { $0.uid == uid }) else { return }
        jump(to: loop)
    }

    /// Forward, single tap — jump to the next loop (by start order). No-op when there
    /// isn't one (or no loop is active — next *song* lands in a later branch).
    func transportNext() {
        guard let uid = TransportNav.next(after: activeLoopID, in: loops.map(\.uid)),
              let loop = loops.first(where: { $0.uid == uid }) else { return }
        jump(to: loop)
    }

    /// Activate `loop` as the transport region and seek to its start, preserving the
    /// current play/pause state (a skip while paused stays paused).
    private func jump(to loop: Loop) {
        let wasPlaying = engine.isPlaying
        activeLoopID = loop.uid
        applyActiveLoopToEngine()
        engine.seek(toSeconds: loop.startSeconds)
        if wasPlaying { engine.play() }
        haptic(.light)
    }

    // MARK: Waveform-touch bracket (swipe-back guard)

    /// A finger landed on the waveform — arm the swipe-back guard (ADR 0030).
    func beginWaveformTouch() { isScrubbing = true }

    /// The waveform touch ended — release the guard.
    func endWaveformTouch() { isScrubbing = false }
}
