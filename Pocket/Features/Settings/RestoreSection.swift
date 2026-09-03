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
        case done(RestoreOutcome)
    }

    @Environment(\.modelContext) private var context

    @State private var phase: Phase = .idle
    @State private var isChoosing = false
    @State private var pending: PendingRestore?
    @State private var failure: String?

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
            case let .success(url): inspect(url)
            case .failure: failure = RestoreFailure.notAnArchive.message
            }
        }
        .sheet(item: $pending) { arrival in
            ArchiveRestorePreviewSheet(pending: arrival) { restore(arrival) }
        }
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
        case .reading:
            HStack(spacing: 10) {
                ProgressView()
                Text("Reading…").foregroundStyle(PocketColor.textSecondary)
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

    private func inspect(_ url: URL) {
        phase = .reading
        switch RestoreCoordinator.inspect(url, in: context) {
        case let .success(arrival):
            phase = .idle
            pending = arrival
        case let .failure(reason):
            phase = .idle
            failure = reason.message
        }
    }

    private func restore(_ arrival: PendingRestore) {
        phase = .done(RestoreCoordinator.restore(arrival, in: context))
        pending = nil
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
