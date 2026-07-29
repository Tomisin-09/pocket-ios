import Foundation
import SwiftData

/// The practice model's **audio loading** — resolving the imported file's
/// security-scoped bookmark (or rendering the dev demo sample) and handing it to
/// the engine — split out of `WaveformPracticeModel.swift` for file length, like
/// the `+Transport` / `+Actions` splits.
///
/// Failure is a first-class state here (audit 2026-07-05): a bookmark that no
/// longer resolves or a file that won't read sets `audioLoadFailed` so the view
/// can say so, instead of leaving a silently dead transport. A **stale** bookmark
/// that still resolves is re-minted on the spot — `SongRef` identity excludes the
/// bookmark bytes, so a refresh never orphans loops/markers.
extension WaveformPracticeModel {

    /// Hand the song's audio to the engine: the resolved real file for an imported
    /// song, or the generated dev sample for the demo (`bookmark == nil`). Skipped
    /// in previews.
    func loadAudio() async {
        guard !isPreview, engine.duration == 0 else { return }
        isLoadingAudio = true
        defer { isLoadingAudio = false }
        if let bookmark = song.ref.bookmark {
            await loadImportedFile(bookmark: bookmark)
        } else {
            await loadDemoSample()
        }
        engine.setRate(speed)
        // Whole-song repeat (ADR 0124) rides the engine's natural-end callback: it fires only on a
        // straight-through finish, never on a manual stop/seek and never while a loop is armed.
        engine.onReachedEnd = { [weak self] in self?.handleReachedEnd() }
    }

    /// Resolve the security-scoped bookmark and load the real file. Access is held
    /// open (`fileAccess`) for the engine's lazy reads, released on deinit. The
    /// engine opens the file off the main actor; `amplitudes` already holds the
    /// waveform extracted at import (set in `init`).
    private func loadImportedFile(bookmark: Data) async {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale),
              let access = SecurityScopedAccess(url) else {
            AudioPlumbing.log.error("Practice: song bookmark failed to resolve — audio unavailable")
            audioLoadFailed = true
            return
        }
        fileAccess = access
        sourceURL = url
        if isStale { refreshStaleBookmark(url: url) }
        await refreshWaveformIfOutdated(url: url)
        do {
            try await engine.load(url: url)
        } catch {
            AudioPlumbing.log.error("Practice: song audio failed to load: \(error.localizedDescription)")
            audioLoadFailed = true
        }
    }

    /// A resolved-but-**stale** bookmark still opens today but may stop resolving
    /// after the next file move / iCloud eviction — re-mint it from the live URL
    /// while we can. Safe by design: `SongRef` equality excludes the bookmark, so
    /// the song's loops/markers are untouched. A failed refresh keeps the old
    /// (still-working) bookmark and just logs.
    private func refreshStaleBookmark(url: URL) {
        do {
            song.bookmark = try url.bookmarkData()
            try context.save()
        } catch {
            AudioPlumbing.log.error("Practice: stale bookmark refresh failed: \(error.localizedDescription)")
        }
    }

    /// Re-extract the stored waveform when it predates the current reduction (ADR
    /// 0017). A bucket count other than `WaveformExtractor.defaultBuckets` means the
    /// song was imported under the old peak-based envelope, so we re-reduce from the
    /// file and persist — self-healing without a separate schema-version field. The
    /// decode runs off the main actor; a failure leaves the old waveform in place.
    private func refreshWaveformIfOutdated(url: URL) async {
        guard song.amplitudes.count != WaveformExtractor.defaultBuckets else { return }
        guard let extracted = try? await Task.detached(priority: .utility, operation: {
            try WaveformExtractor.extract(from: url)
        }).value else { return }
        song.amplitudes = extracted.amplitudes
        amplitudes = extracted.amplitudes
        try? context.save()
    }

    /// Generate the dev arpeggio off the main actor and hand it to the engine (the
    /// demo sample). The render writes a WAV, so it's kept off the main thread too.
    private func loadDemoSample() async {
        guard let sample = try? await SampleToneGenerator.makeDemoSample(duration: song.duration) else {
            AudioPlumbing.log.error("Practice: demo sample render failed — audio unavailable")
            audioLoadFailed = true
            return
        }
        amplitudes = sample.amplitudes
        sourceURL = sample.url
        do {
            try await engine.load(url: sample.url)
        } catch {
            AudioPlumbing.log.error("Practice: demo sample failed to load: \(error.localizedDescription)")
            audioLoadFailed = true
        }
    }
}
