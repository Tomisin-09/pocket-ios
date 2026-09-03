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

    /// The throwaway directory holding this door's own copy of the archive. Deleting it is the whole
    /// of the cleanup — `RestoreCoordinator.discard` is one `removeItem`, the same shape
    /// `ExportedArchive.workingDirectory` takes on the way out.
    let workingDirectory: URL
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

    /// Open an archive and work out what it would do, writing nothing into the library.
    ///
    /// **The archive is copied into `tmp/` first, and that is not tidiness.** A picked file lives
    /// outside the app's container behind a security scope the picker grants for the duration of the
    /// call; `ZipArchiveReader` memory-maps what it opens, and a restore then reads take audio out of
    /// that map *later*, after the player has confirmed — by which time the scope is long closed. A
    /// map into a file the app is no longer permitted to read is exactly the failure that works on a
    /// local file in a test and fails on an iCloud Drive archive on a device.
    ///
    /// The copy also removes a second problem the sheet would otherwise have: the player can replace
    /// the file between seeing the summary and confirming it, and a restore must write the archive it
    /// showed them rather than whatever is at that path now.
    ///
    /// S2's receive door does the equivalent by reading a whole `.redmoonpractice` file into memory
    /// inside the scope. That is the same fix at a size where a copy is not worth naming; an archive
    /// is as large as the library it came from, which is why this one is a file rather than a `Data`.
    /// **Read off the main actor, plan on it.** Copying a library-sized zip and inflating its
    /// `practice.json` is exactly the work `ExportSection` already refuses to do on the main thread
    /// (`ArchiveBuilder` reads on it, `ArchiveWriter` writes off it). Only the last step needs the
    /// actor, because only it touches the store.
    static func inspect(_ url: URL, in context: ModelContext) async -> Result<PendingRestore, RestoreFailure> {
        let opened = await Task.detached(priority: .userInitiated) { open(url) }.value

        switch opened {
        case let .success(opened):
            return .success(PendingRestore(
                read: opened.read,
                plan: RestorePlan.make(for: opened.read.archive,
                                       existing: ArchiveRestoreWriter.existingKeys(in: context),
                                       takeAudio: Set(opened.read.takeAudio.keys)),
                workingDirectory: opened.workingDirectory))
        case let .failure(failure):
            return .failure(failure)
        }
    }

    /// An archive copied into `tmp/` and opened, or the reason it could not be.
    struct OpenedArchive: Sendable {
        let read: ReadArchive
        let workingDirectory: URL
    }

    /// The copy and the read, with no actor and no store — the half that can run anywhere.
    nonisolated static func open(_ url: URL,
                                 fileManager: FileManager = .default) -> Result<OpenedArchive, RestoreFailure> {
        let working = fileManager.temporaryDirectory
            .appending(path: "RedMoonRestore-\(UUID().uuidString)", directoryHint: .isDirectory)
        let local = working.appending(path: "archive.zip", directoryHint: .notDirectory)

        let scoped = url.startAccessingSecurityScopedResource()
        do {
            try fileManager.createDirectory(at: working, withIntermediateDirectories: true)
            try fileManager.copyItem(at: url, to: local)
        } catch {
            if scoped { url.stopAccessingSecurityScopedResource() }
            try? fileManager.removeItem(at: working)
            return .failure(.notAnArchive)
        }
        if scoped { url.stopAccessingSecurityScopedResource() }

        switch ArchiveRestoreReader.read(contentsOf: local) {
        case let .success(read):
            return .success(OpenedArchive(read: read, workingDirectory: working))
        case let .failure(failure):
            // A half-opened archive is still a full-size copy of one, and `tmp/` is not somewhere the
            // player can see or reclaim — the same argument `ArchiveWriter` makes on its error path.
            try? fileManager.removeItem(at: working)
            return .failure(failure)
        }
    }

    /// Throw the door's copy away.
    ///
    /// Takes the directory rather than the `PendingRestore` on purpose: the caller has to be able to
    /// clean up **after** `.sheet(item:)` has nilled its binding, which it does before `onDismiss`
    /// runs. A cleanup that could only be expressed in terms of the thing already gone is a cleanup
    /// that never runs.
    ///
    /// Idempotent and non-throwing, like `ArchiveWriter.cleanUp`: there is nothing a caller could
    /// usefully do about a failure here, and a cleanup that can throw is a cleanup that gets skipped
    /// on the path where it matters most.
    static func discard(_ workingDirectory: URL) {
        try? FileManager.default.removeItem(at: workingDirectory)
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
        async -> RestoreOutcome {
        let landing = ArchiveRestoreWriter.materialize(pending.read,
                                                       existing: ArchiveRestoreWriter.existingKeys(in: context),
                                                       resolver: RestoreResolver(existing: context))
        var outcome = RestoreOutcome(rowsAdded: landing.rowCount)

        landing.insert(into: context)
        // Saved before a single byte is written, which is D7's rule stated as code.
        try? context.save()

        // Everything below is plain values — `ZipArchiveReader`, `ZipEntry` and `URL` are all
        // `Sendable` — so inflating and writing a library's worth of take audio happens off the main
        // actor, with the rows it belongs to already safely in the store. On an archive that is
        // mostly recordings this is the difference between a restore that spins and one that hangs.
        let takes = landing.takeAudio
        let attachments = landing.referenceImages
        let zip = pending.read.zip
        let files = await Task.detached(priority: .userInitiated) {
            ArchiveRestoreFiles.write(takes: takes, attachments: attachments, from: zip,
                                      takesDirectory: takesDirectory,
                                      attachmentsDirectory: attachmentsDirectory)
        }.value
        outcome.takeFilesWritten = files.written.count
        outcome.filesFailed = files.failed.count
        return outcome
    }
}
