import Foundation
import SwiftData

/// An archive that has been read and priced, waiting for the player's yes (ADR 0188 D9).
///
/// The plan and the opened zip travel together because the confirmation and the write must be the
/// same reading of the same file: re-opening it to do the work would re-inflate every entry and, on a
/// file the player could have replaced in between, could write something they were never shown.
@MainActor
struct PendingRestore: Identifiable {
    /// Per-arrival, not derived from the file. Choosing the same archive twice is two presentations.
    let id = UUID()
    let read: ReadArchive
    let plan: RestorePlan
}

/// What a restore actually did.
@MainActor
struct RestoreOutcome: Equatable {
    var rowsAdded: Int = 0
    var takeFilesWritten: Int = 0
    var filesFailed: Int = 0
}

/// Reading an archive, pricing it, and — once the player says yes — writing it (ADR 0188 S3).
///
/// The order below is D7's, and it is the whole of this type's job:
///
/// 1. rows are built (`ArchiveRestoreWriter.materialize`),
/// 2. inserted and **saved**,
/// 3. and only then are the files written out of the zip.
///
/// ADR 0182's `OrphanSweep.run` builds its referenced set from every row in the store, so a take
/// written into `Recordings/` before its row exists is an orphan by the sweep's own definition — and
/// *Reclaim space* is a button the player can press at any moment, including while a restore is
/// running. Saving between the two is what closes that window rather than narrowing it.
@MainActor
enum RestoreCoordinator {

    /// Open an archive and work out what it would do, writing nothing.
    static func inspect(_ url: URL, in context: ModelContext) -> Result<PendingRestore, RestoreFailure> {
        // A picked file lives outside the app's container, so the read needs the scope the picker
        // granted. `.fileImporter` hands back a URL the app may not otherwise touch, and without this
        // the read fails as "not an archive" on a file that is perfectly good.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        return ArchiveRestoreReader.read(contentsOf: url).map { read in
            PendingRestore(read: read,
                           plan: RestorePlan.make(for: read.archive,
                                                  existing: ArchiveRestoreWriter.existingKeys(in: context),
                                                  takeAudio: Set(read.takeAudio.keys)))
        }
    }

    /// Write it.
    ///
    /// The keys are read **again** here rather than carried from `inspect`. The player may have added
    /// or deleted rows between seeing the summary and confirming it, and a stale key set would either
    /// duplicate a row that now exists or skip one that no longer does. The plan governs what the
    /// player was *told*; the store governs what is *written*, and D1's skip is the rule that makes
    /// the two safe to differ.
    static func restore(_ pending: PendingRestore,
                        in context: ModelContext,
                        takesDirectory: URL? = try? RecordingStore.directory(),
                        attachmentsDirectory: URL? = try? ReferenceAttachmentStore.directory())
        -> RestoreOutcome {
        let landing = ArchiveRestoreWriter.materialize(pending.read,
                                                       existing: ArchiveRestoreWriter.existingKeys(in: context),
                                                       resolver: RestoreResolver(existing: context))
        var outcome = RestoreOutcome(rowsAdded: landing.rowCount)

        landing.insert(into: context)
        // Saved before a single byte is written, which is D7's rule stated as code.
        try? context.save()

        let files = ArchiveRestoreFiles.write(takes: landing.takeAudio,
                                              attachments: landing.referenceImages,
                                              from: pending.read.zip,
                                              takesDirectory: takesDirectory,
                                              attachmentsDirectory: attachmentsDirectory)
        outcome.takeFilesWritten = files.written.count
        outcome.filesFailed = files.failed.count
        return outcome
    }
}
