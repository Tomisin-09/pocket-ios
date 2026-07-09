import Foundation

/// A short **strum-rhythm audio preview** (ADR 0071 R5): plays a strumming exercise's pattern as an
/// audible down/up/accent/mute rhythm at its command tempo, so you hear *how* the strum goes before
/// running the routine. It wraps a `StandaloneMetronomeEngine` armed with the pattern (its click
/// follows the slots, rests silent), on its **own** engine so a preview never disturbs a live one, and
/// **auto-stops** after `previewSeconds`.
///
/// Phase 1 is a **rhythm** reference — the metronome click has no pitch, so this conveys the strum
/// groove, not the chord tone (real tones need original recorded audio, a later phase). No evaluation
/// (ADR 0070): it's an audition, nothing is measured.
@MainActor
@Observable
final class StrumPatternPreviewPlayer {
    /// How long a preview plays before stopping itself, seconds — matches the other block previews.
    static let previewSeconds = 10

    private let engine = StandaloneMetronomeEngine()
    private var stopTask: Task<Void, Never>?

    /// Whether the strum is sounding — drives the play/stop glyph.
    var isPlaying: Bool { engine.transport == .playing }

    /// Toggle the audition: arm the pattern and play it at `bpm` in `signature` (auto-stopping after
    /// `previewSeconds`), or stop one already sounding. Tapping again restarts cleanly.
    func toggle(pattern: StrumPattern, signature: TimeSignature, bpm: Int) {
        if isPlaying { stop(); return }
        engine.setTimeSignature(signature)
        engine.setStrumPattern(pattern)
        engine.setBPM(bpm)
        engine.start()
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.previewSeconds))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    /// Stop the audition and cancel its pending auto-stop. Idempotent — safe to call on disappear.
    /// `engine.stop()` clears the armed pattern, so the engine is clean for reuse.
    func stop() {
        stopTask?.cancel()
        stopTask = nil
        engine.stop()
    }
}
