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
        if song.hasImportedAudio {
            await loadImportedFile()
        } else {
            await loadDemoSample()
        }
        engine.setRate(speed)
        // Whole-song repeat (ADR 0124) rides the engine's natural-end callback: it fires only on a
        // straight-through finish, never on a manual stop/seek and never while a loop is armed.
        engine.onReachedEnd = { [weak self] in self?.handleReachedEnd() }
    }

    /// Point the song at a file again and load it, without leaving the practice screen (ADR 0148
    /// §6). Returns the relink outcome so the caller can warn about a length mismatch, or throws
    /// with the song untouched.
    ///
    /// The decode runs off the main actor for the same reason import does — `WaveformExtractor`
    /// reads the whole file, and a multi-megabyte extract on the main thread is a visible stall.
    /// `amplitudes` is re-read from the song afterwards: the waveform on screen is drawn from the
    /// model's copy, and a relink that redrew nothing would show the old envelope over new audio.
    @discardableResult
    func relinkAudio(to url: URL) async throws -> SongRelinker.Outcome {
        // Swap the failure notice for the loading overlay **before** any work starts. Decoding a
        // multi-megabyte file takes seconds, and without this the notice sat there with a live
        // "Find the file" button through all of it — so the picker closing looked like nothing had
        // happened, and the obvious response was to pick the file again (device pass 2026-08-07).
        audioLoadFailed = false
        isLoadingAudio = true
        defer { isLoadingAudio = false }

        do {
            // Only the id crosses the boundary — a `Song` and a `ModelContext` are not `Sendable`.
            let sourceID = song.sourceID
            let prepared = try await Task.detached(priority: .userInitiated) {
                try SongRelinker.prepare(from: url, sourceID: sourceID)
            }.value

            let outcome = SongRelinker.apply(prepared, to: song, in: context)
            amplitudes = song.amplitudes
            engine.stop()
            await loadImportedFile()
            return outcome
        } catch {
            // Put the notice back: the song is exactly as broken as it was, and hiding that behind
            // a dismissed alert would leave a dead transport — the thing the notice exists to stop.
            audioLoadFailed = true
            throw error
        }
    }

    /// Locate the song's audio and load the real file. Access is held open (`fileAccess`) for the
    /// engine's lazy reads, released on deinit — `nil` for a copy Pocket owns, which needs no
    /// security scope. The engine opens the file off the main actor; `amplitudes` already holds
    /// the waveform extracted at import (set in `init`).
    private func loadImportedFile() async {
        guard let resolved = SongAudioResolver.resolve(song) else {
            AudioPlumbing.log.error("Practice: song audio could not be located — unavailable")
            audioLoadFailed = true
            return
        }
        fileAccess = resolved.access
        sourceURL = resolved.url
        // While the file is provably readable — the one moment a pre-0148 song can be copied in.
        SongAudioResolver.adoptIfNeeded(song, resolved: resolved)
        await refreshWaveformIfOutdated(url: resolved.url)
        do {
            try await engine.load(url: resolved.url)
        } catch {
            AudioPlumbing.log.error("Practice: song audio failed to load: \(error.localizedDescription)")
            audioLoadFailed = true
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
