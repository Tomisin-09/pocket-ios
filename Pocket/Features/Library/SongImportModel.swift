import Foundation
import SwiftData

/// Progress of an in-flight batch import, for the "Importing N of M…" overlay.
struct SongImportProgress: Equatable {
    var completed: Int
    var total: Int
}

/// Outcome of a finished batch import. Pure value type (no SwiftData) so the
/// user-facing alert is unit-testable. `isReportable` is false only when nothing
/// happened (an empty pick) — otherwise the completion alert confirms success and/or
/// lists what was skipped.
struct SongImportSummary: Equatable {
    var imported: Int
    /// File names that couldn't be read (empty file, DRM, unsupported codec…).
    var failedNames: [String]

    /// Whether there's anything worth surfacing to the user.
    var isReportable: Bool { imported > 0 || !failedNames.isEmpty }

    /// One song picked, one song imported, nothing skipped — the case that "opens on create": the
    /// caller pushes that song's waveform instead of leaving the user on a list to find it. A batch
    /// never opens (which of the five?), and neither does a run with skipped files, whose summary
    /// alert has something to say first.
    var isSingleCleanImport: Bool { imported == 1 && failedNames.isEmpty }

    /// Alert title — celebratory on a clean import, cautionary when files were
    /// skipped (whether or not any succeeded).
    var title: String {
        failedNames.isEmpty ? "Songs added" : "Some files were skipped"
    }

    /// Alert body: confirms how many songs imported and, if any failed, names them.
    var message: String {
        let importedPhrase = imported > 0
            ? "Imported \(imported == 1 ? "1 song" : "\(imported) songs")."
            : nil
        guard !failedNames.isEmpty else { return importedPhrase ?? "" }
        let failedCount = failedNames.count
        let couldnt = failedCount == 1
            ? "1 file couldn’t be read"
            : "\(failedCount) files couldn’t be read"
        let names = failedNames.joined(separator: ", ")
        if let importedPhrase {
            return "\(importedPhrase) \(couldnt): \(names)."
        }
        return "\(couldnt): \(names)."
    }
}

/// Drives a multi-select song import (ADR 0011 Slice 2). Decoding each file is the
/// expensive step, so it runs off the main actor via `Task.detached`; only the
/// SwiftData insert hops back here. Owns the progress + summary UI state so
/// `LibraryView` stays lean.
@MainActor
@Observable
final class SongImportModel {

    /// Non-nil while a batch is running — drives the progress overlay.
    private(set) var progress: SongImportProgress?
    /// Set when a batch finishes with something worth telling the user (failures).
    var summary: SongImportSummary?
    /// The songs this batch actually created, in pick order. Kept off `SongImportSummary` so that
    /// stays a pure, unit-testable value type; it exists so a caller can **open** what it just
    /// imported when a single file was picked. Reset at the start of every run.
    private(set) var importedSongs: [Song] = []

    /// Import `urls` into `context`. Good files still import when others fail; the
    /// failures are collected into `summary`. Extraction is off-main so the UI stays
    /// responsive and the progress overlay can animate. Returns the outcome so a
    /// caller can react (e.g. the home hub navigates to the library when something
    /// actually imported), with `importedSongs` naming what it created.
    @discardableResult
    func run(urls: [URL], into context: ModelContext) async -> SongImportSummary {
        importedSongs = []
        guard !urls.isEmpty else { return SongImportSummary(imported: 0, failedNames: []) }
        progress = SongImportProgress(completed: 0, total: urls.count)
        var imported = 0
        var failedNames: [String] = []

        for (index, url) in urls.enumerated() {
            do {
                let prepared = try await Task.detached(priority: .userInitiated) {
                    try SongImporter.prepare(from: url)
                }.value
                importedSongs.append(SongImporter.persist(prepared, into: context))
                imported += 1
            } catch {
                failedNames.append(SongImporter.title(for: url))
            }
            progress?.completed = index + 1
        }

        progress = nil
        let outcome = SongImportSummary(imported: imported, failedNames: failedNames)
        // Counts only (ADR 0120) — `failedNames` are the player's own file names and must never
        // leave the device. Reported here, the single completion point, rather than at the two
        // callers (Home and Library), which would double-count.
        Analytics.send(.songImported(count: outcome.imported, failed: outcome.failedNames.count))
        if outcome.isReportable { summary = outcome }
        return outcome
    }

    /// The song to **open** after a finished import, or `nil` when the batch shouldn't open one
    /// (`SongImportSummary.isSingleCleanImport`). Consuming it also drops the completion alert: the
    /// waveform screen appearing *is* the confirmation, so "Imported 1 song." over the top of it is
    /// noise. Nothing is dropped when files were skipped — that summary still has news.
    func takeSongToOpen(after outcome: SongImportSummary) -> Song? {
        guard outcome.isSingleCleanImport, let song = importedSongs.first else { return nil }
        summary = nil
        return song
    }
}
