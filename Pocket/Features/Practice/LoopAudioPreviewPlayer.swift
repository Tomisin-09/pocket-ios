import Foundation

/// A short **loop audio audition** for the pre-start block preview (ADR 0071 R4b): plays a few
/// seconds of the loop's **actual audio** (the looping region, at its command speed) so you hear
/// what a loop block is before running the routine — no metronome click, the real thing. It wraps a
/// `LoopRunModel` (which owns a private `PracticeAudioEngine` and handles region loading / looping),
/// so a preview never disturbs a live run, and it **auto-stops** after `previewSeconds`.
///
/// Loops are DRM-free local/iCloud files (ADR 0001), so auditioning the audio is allowed. No
/// evaluation (ADR 0070): it's an audition, nothing is measured.
@MainActor
@Observable
final class LoopAudioPreviewPlayer {
    /// How long an audition plays before stopping itself, seconds — the top of the ADR 0071 window.
    static let previewSeconds = 10

    private let model: LoopRunModel
    private let commandPercent: Int
    private var stopTask: Task<Void, Never>?

    init(loop: Loop) {
        model = LoopRunModel(loop: loop)
        commandPercent = loop.ramp.command
    }

    /// Whether audio is sounding — drives the play/stop glyph.
    var isPlaying: Bool { model.isRunning }
    /// True once the loop's audio couldn't be resolved (moved/deleted file) — the button says so
    /// rather than offering a silent dead preview.
    var isUnavailable: Bool { model.loadFailed }

    /// Toggle the audition: load the region if needed, play it at command speed (auto-stopping after
    /// `previewSeconds`), or stop one already sounding. Tapping again restarts cleanly.
    func toggle() {
        if isPlaying { stop(); return }
        stopTask = Task { [weak self] in
            guard let self else { return }
            await model.loadIfNeeded()
            guard !Task.isCancelled, !model.loadFailed else { return }
            model.startAudition(percent: commandPercent)
            try? await Task.sleep(for: .seconds(Self.previewSeconds))
            guard !Task.isCancelled else { return }
            stop()
        }
    }

    /// Stop the audition and cancel its pending auto-stop. Idempotent — safe to call on disappear.
    func stop() {
        stopTask?.cancel()
        stopTask = nil
        model.stop()
    }
}
