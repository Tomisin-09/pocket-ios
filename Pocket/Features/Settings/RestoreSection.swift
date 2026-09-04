import SwiftData
import SwiftUI

/// **Settings ▸ Your data ▸ Restore** — reading an archive back (ADR 0188 S3).
///
/// The half ADR 0181 named in its own Consequences as missing: *export without import is half a
/// loop*. It sits directly under Export because the two are one operation seen from either end, and a
/// player looking for the way back in looks where the way out was.
///
/// ### One door, and it is the picker
///
/// Unlike a shared routine (S2, D3), an archive arrives through `.fileImporter` **only**. A
/// `.redmoonpractice` file is a type this app owns and declares; an archive is a plain `.zip`, and
/// declaring the app a handler for every zip on the phone is exactly the over-broad capability
/// AGENTS.md forbids — Red Moon would appear in the Open-with list for a folder of holiday photos.
/// So restoring is something the player comes here to do, which is also the right weight for an
/// operation that touches the whole library.
///
/// ### Nothing here destroys anything
///
/// D6 ships merge and no replace. A row whose id the library already has is skipped, which makes a
/// restore idempotent — running it twice leaves the library exactly as running it once did — and
/// means this screen never needs a confirmation about losing anything, because there is nothing to
/// lose.
struct RestoreSection: View {

    private enum Phase: Equatable {
        case idle
        case reading
        case restoring
        case done(RestoreOutcome)
    }

    @Environment(\.modelContext) private var context

    @State private var phase: Phase = .idle
    @State private var isChoosing = false
    @State private var pending: PendingRestore?
    @State private var failure: String?
    /// Held beside `pending` because cleanup has to outlive it: `.sheet(item:)` nils its binding
    /// before `onDismiss` runs, so a discard expressed in terms of `pending` would find nothing.
    @State private var working: URL?

    var body: some View {
        Section {
            action
        } header: {
            Text("Restore")
        } footer: {
            Text(footer)
        }
        // A zip, because that is what an archive is. `.data` is not offered as a fallback: a picker
        // that accepts anything is a picker that reports "not an archive" at a player who was allowed
        // to choose a photo.
        .fileImporter(isPresented: $isChoosing, allowedContentTypes: [.zip]) { result in
            switch result {
            case let .success(url): Task { await inspect(url) }
            case .failure: failure = RestoreFailure.notAnArchive.message
            }
        }
        // `onDismiss` runs after the sheet has closed — after `restore` if the player confirmed, and
        // straight away if they cancelled — so it is the one place that catches both endings. The
        // copy in `tmp/` is a second full-size archive, and `tmp/` is not somewhere a player can see
        // or reclaim; `ExportSection` throws its export away on exactly the same reasoning.
        .sheet(item: $pending, onDismiss: discardPending) { arrival in
            ArchiveRestorePreviewSheet(pending: arrival) {
                // The phase is set **synchronously**, before the task is spawned, because the sheet
                // dismisses itself on the next line and `onDismiss` must be able to see that a
                // restore is in flight. Setting it inside the task would leave a window where the
                // cleanup below deletes the archive the write is still reading.
                phase = .restoring
                Task { await restore(arrival) }
            }
        }
        .onDisappear { discardPending() }
        .alert("Couldn’t open that archive", isPresented: presenting($failure)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    @ViewBuilder
    private var action: some View {
        switch phase {
        case .idle, .done:
            Button("Restore from a copy…") { isChoosing = true }
        case .reading, .restoring:
            HStack(spacing: 10) {
                ProgressView()
                Text(phase == .reading ? "Reading…" : "Restoring…")
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
    }

    /// One line, and after a restore it is the receipt.
    ///
    /// Said here rather than in an alert because it is a fact about the library that stays true —
    /// an alert would deliver the same sentence and then take it away.
    private var footer: String {
        switch phase {
        case let .done(outcome) where outcome.rowsAdded == 0:
            return "Everything in that archive was already here, so nothing changed."
        case let .done(outcome):
            let takes = outcome.takeFilesWritten
            return "Added \(outcome.rowsAdded) item\(outcome.rowsAdded == 1 ? "" : "s")"
                + (takes == 0 ? "." : ", and \(takes) recording\(takes == 1 ? "" : "s").")
        default:
            return "Choose an archive you exported earlier. Red Moon adds anything it doesn't "
                + "already have and leaves the rest alone, so nothing is replaced and restoring the "
                + "same file twice changes nothing the second time. Songs come back with their loops "
                + "and notes; their audio doesn't travel in an archive, so you'll point them at your "
                + "own files again."
        }
    }

    private func inspect(_ url: URL) async {
        phase = .reading
        switch await RestoreCoordinator.inspect(url, in: context) {
        case let .success(arrival):
            phase = .idle
            working = arrival.workingDirectory
            pending = arrival
        case let .failure(reason):
            phase = .idle
            failure = reason.message
        }
    }

    /// `pending` is deliberately **not** cleared here. The sheet dismisses itself, and
    /// `.sheet(item:)` nils the binding as it goes; doing both would set the same state twice while
    /// the dismissal is animating. `RoutineReceiveHost` leaves it to the sheet for the same reason.
    ///
    /// The zip is still open at this point and has to be: the files are written out of it *after* the
    /// rows are saved (D7). `discardPending` runs later, from `onDismiss`.
    /// The files are written out of the zip **after** the rows are saved (D7), so the archive has to
    /// stay on disk for the whole of this — which is why the discard is here and not in `onDismiss`.
    private func restore(_ arrival: PendingRestore) async {
        let outcome = await RestoreCoordinator.restore(arrival, in: context)
        // `alreadyPresent` comes off the plan rather than the outcome: it is what the skip rule left
        // alone, which is the number that separates a recovery onto a new phone from a merge into a
        // library that is already there (ADR 0188 D6).
        Analytics.send(.archiveRestored(itemsAdded: outcome.rowsAdded,
                                        alreadyPresent: arrival.plan.alreadyPresentCount,
                                        takeFiles: outcome.takeFilesWritten))
        phase = .done(outcome)
        RestoreCoordinator.discard(arrival.workingDirectory)
        working = nil
    }

    /// Delete the door's copy of the archive when the sheet closed **without** a restore.
    ///
    /// A restore in flight is still reading that copy, and cleans up after itself when it finishes.
    /// Deleting it here as well would be racing the one operation this door exists to complete.
    private func discardPending() {
        guard phase != .restoring, let working else { return }
        RestoreCoordinator.discard(working)
        self.working = nil
    }

    /// A `Bool` binding that clears the message when the alert closes — the same helper shape
    /// `RoutineReceiveHost` uses, kept local so neither owns the other's state.
    private func presenting(_ message: Binding<String?>) -> Binding<Bool> {
        Binding(get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } })
    }
}

#Preview {
    Form { RestoreSection() }
        .preferredColorScheme(.dark)
        .modelContainer(for: Song.self, inMemory: true)
}
