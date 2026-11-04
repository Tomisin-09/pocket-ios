import Foundation
import SwiftData

/// Progress of an in-flight batch import, for the import card.
struct SongImportProgress: Equatable {
    var completed: Int
    var total: Int
    /// The file being decoded now, by the name it will import under, or `nil` when there isn't one to
    /// name (share-in reads one file before it has a title). The card names it: a count that sits on
    /// "0 of 1" for a long decode looks stuck, and the name says what the wait is for.
    var current: String?

    /// The card's main line: *Importing “Binta”*, or *Importing…* with no name to give.
    var headline: String {
        current.map { "Importing “\($0)”" } ?? "Importing…"
    }

    /// Where the batch is, *2 of 5*, counting the file in progress; `nil` for a single file, where it
    /// would only ever say *1 of 1*.
    var position: String? {
        guard total > 1 else { return nil }
        return "\(min(completed + 1, total)) of \(total)"
    }
}

/// Outcome of a finished batch import. Pure value type (no SwiftData) so what it says is
/// unit-testable. `isReportable` is false only when nothing happened (an empty pick). Its
/// `title` heads the finished import sheet, and VoiceOver hears its `message` when a batch
/// finishes (ADR 0290); it was a completion alert before the sheet.
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

    /// The finished sheet's title — celebratory on a clean import, cautionary when files were
    /// skipped (whether or not any succeeded).
    var title: String {
        failedNames.isEmpty ? "Songs added" : "Some files were skipped"
    }

    /// What VoiceOver hears when a batch finishes: how many songs imported and, if any failed, which.
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
/// SwiftData insert hops back here. Owns the card and the import sheet's state so
/// `LibraryView` stays lean.
///
/// **One file reads under the card; several, under the import sheet** (ADR 0290). The sheet lists every
/// file as it's read, says why one was skipped, and opens any song that was added. A single file keeps
/// the card and opens on its waveform, as it always has, and only shows the sheet when it was skipped:
/// a sheet raised and then closed for one quick file would flash.
@MainActor
@Observable
final class SongImportModel {

    /// Non-nil while a single file is read: drives the card.
    private(set) var progress: SongImportProgress?
    /// Every file of the last import and how it went: the import sheet's rows.
    private(set) var batch: SongImportBatch?
    /// The import sheet is up.
    var showingSheet = false
    /// What the last import came to, read when its sheet closes.
    private(set) var lastOutcome: SongImportSummary?
    /// The songs this batch actually created, in pick order. Kept off `SongImportSummary` so that
    /// stays a pure, unit-testable value type; it exists so a caller can **open** what it just
    /// imported when a single file was picked. Reset at the start of every run.
    private(set) var importedSongs: [Song] = []
    /// The song each added file became, by its place in the pick, for opening from the sheet.
    private var songsByFile: [Int: Song] = [:]
    /// A song tapped in the sheet, opened once the sheet has gone: a push can't start under a sheet.
    private var opening: Song?

    /// Import `urls` into `context`. Good files still import when others fail; the
    /// failures are collected into `summary`. Extraction is off-main so the UI stays
    /// responsive and the progress overlay can animate. Returns the outcome so a
    /// caller can react (e.g. the home hub navigates to the library when something
    /// actually imported), with `importedSongs` naming what it created.
    @discardableResult
    func run(urls: [URL], into context: ModelContext) async -> SongImportSummary {
        importedSongs = []
        songsByFile = [:]
        opening = nil
        guard !urls.isEmpty else { return SongImportSummary(imported: 0, failedNames: []) }
        let names = urls.map(SongImporter.title(for:))
        batch = SongImportBatch(names: names)
        if urls.count == 1 {
            progress = SongImportProgress(completed: 0, total: 1)
        } else {
            showingSheet = true
        }

        for (index, url) in urls.enumerated() {
            progress?.current = names[index]
            batch?.reading(index)
            do {
                let prepared = try await Task.detached(priority: .userInitiated) {
                    try SongImporter.prepare(from: url)
                }.value
                let song = SongImporter.persist(prepared, into: context)
                importedSongs.append(song)
                songsByFile[index] = song
                batch?.added(index)
            } catch {
                batch?.skipped(index, because: error)
            }
            progress?.completed = index + 1
        }

        progress = nil
        let outcome = batch?.summary ?? SongImportSummary(imported: 0, failedNames: [])
        lastOutcome = outcome
        // One file that was skipped says why in the sheet, where a batch would.
        if urls.count == 1, !outcome.failedNames.isEmpty { showingSheet = true }
        return outcome
    }

    /// A song tapped in the sheet: close the sheet, and open the song once it's gone (`takeOpening`).
    func open(_ file: Int) {
        guard let song = songsByFile[file] else { return }
        opening = song
        showingSheet = false
    }

    /// The song tapped in the sheet, for its `onDismiss` to open, or `nil` when it closed with *Done*.
    func takeOpening() -> Song? {
        defer { opening = nil }
        return opening
    }

    /// The song to **open** after a finished import, or `nil` when the batch shouldn't open one
    /// (`SongImportSummary.isSingleCleanImport`). The waveform screen appearing *is* the confirmation, so
    /// a single clean import shows nothing else.
    func takeSongToOpen(after outcome: SongImportSummary) -> Song? {
        guard outcome.isSingleCleanImport, let song = importedSongs.first else { return nil }
        return song
    }
}
