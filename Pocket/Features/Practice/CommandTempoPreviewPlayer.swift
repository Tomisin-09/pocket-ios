import Foundation

/// A short, self-contained **metronome audio preview** (ADR 0071 R4): plays a steady click at a
/// given command tempo for a few seconds so you can *hear* what an exercise is aiming at straight
/// from its detail sheet — without opening the run screen and starting a real session. It owns its
/// **own** `StandaloneMetronomeEngine`, so a preview never disturbs a live practice engine, and it
/// **auto-stops** after `previewSeconds` (a preview, not a run — the full working→command→reach climb
/// stays on the run screen). No evaluation (ADR 0070): it's an audition, nothing is measured.
@MainActor
@Observable
final class CommandTempoPreviewPlayer {
    /// How long a preview plays before stopping itself, seconds — the top of the ADR 0071 5–10s window.
    static let previewSeconds = 10

    private let engine = StandaloneMetronomeEngine()
    private var stopTask: Task<Void, Never>?

    /// Whether a preview is currently sounding — drives the play/stop button glyph.
    var isPlaying: Bool { engine.transport == .playing }

    /// Toggle a preview at `bpm` in `signature`: start a fresh steady click (auto-stopping after
    /// `previewSeconds`), or stop one already sounding. Tapping mid-preview stops it; tapping again
    /// restarts cleanly at the current tempo.
    func toggle(bpm: Int, signature: TimeSignature) {
        if isPlaying { stop(); return }
        engine.setTimeSignature(signature)
        engine.setBPM(bpm)
        engine.start()
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.previewSeconds))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    /// Stop the preview and cancel its pending auto-stop. Idempotent — safe to call on disappear.
    func stop() {
        stopTask?.cancel()
        stopTask = nil
        engine.stop()
    }
}
