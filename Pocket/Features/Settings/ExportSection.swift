import SwiftData
import SwiftUI

/// **Settings ▸ Your data ▸ Export** — a copy of everything, as one file the player keeps (ADR 0181).
///
/// Until this shipped, Red Moon was a closed box: a library, years of journal entries and every take
/// lived in one unreplicated store, and nothing could get out. The schema is frozen against
/// destructive changes for exactly that reason — a bad migration was unrecoverable. This is the way
/// out, and it is deliberately the *whole* thing rather than a per-item share.
///
/// ### Two taps, not one
///
/// `ShareLink` needs its file to exist before the row is built, and building an archive of a real
/// library is not instant work. So preparing and sharing are separate: *Prepare a copy* does the
/// work and reports what it produced, and only then does a share row appear. The alternative — a
/// button that silently spins and then throws up a share sheet — hides both the cost and the result.
///
/// ### What leaves the device: nothing, until the player says so
///
/// The archive is written to `tmp/` and handed to the system share sheet. The app transmits nothing
/// and has no idea where it goes. That is the distinction ADR 0150 rested on, and it is why the
/// published privacy page's "no audio upload path" line stays true.
struct ExportSection: View {

    /// Where the export is up to. `ExportedArchive` is `Equatable`, so the whole thing compares.
    private enum Phase: Equatable {
        case idle
        case preparing
        case ready(ExportedArchive)
        case failed(String)
    }

    @Environment(\.modelContext) private var context

    /// Deliberately **not** `@AppStorage`. This is a choice about one export, not a standing
    /// preference, and the honest default is the one that produces a complete archive.
    @State private var includesRecordings = true
    @State private var phase: Phase = .idle
    @State private var usage: StorageUsage = .none

    var body: some View {
        Section {
            Toggle(isOn: $includesRecordings) {
                FieldInfoLabel(title: "Include recordings", info: SettingsInfo.exportRecordings)
            }
            .disabled(phase == .preparing)
            .onChange(of: includesRecordings) { _, _ in discard() }

            LabeledContent("Size") {
                Text(StorageUsage.approximate(bytes: estimatedBytes))
                    .foregroundStyle(PocketColor.textSecondary)
            }

            action
        } header: {
            Text("Export")
        } footer: {
            Text(footer)
        }
        .task { await measure() }
        // `tmp/` is invisible to the player and a stranded archive is a second copy of the library,
        // so leaving the screen throws it away. Preparing again is cheap; a full disk is not.
        .onDisappear { discard() }
    }

    /// The row that changes with the phase — one row, so the section does not reflow around it.
    @ViewBuilder
    private var action: some View {
        switch phase {
        case .idle, .failed:
            Button("Prepare a copy") { Task { await prepare() } }
        case .preparing:
            HStack(spacing: 10) {
                ProgressView()
                Text("Preparing…").foregroundStyle(PocketColor.textSecondary)
            }
        case let .ready(export):
            ShareLink(item: export.zipURL) {
                LabeledContent("Save or share") {
                    Text(StorageUsage.formatted(bytes: export.byteCount))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
        }
    }

    /// One line under the section, and it has three jobs: say what is in the file, warn about the
    /// thing ADR 0150 asked to be warned about, and point at the way back in.
    ///
    /// **That third job used to be an apology** — *"Red Moon can't read one back in yet"* — and it was
    /// one of three places that sentence lived (ADR 0188's Consequences names all three, because
    /// fixing one of them was the likely failure). This is the copy a player actually reads, and the
    /// one no docs checklist covers.
    private var footer: String {
        switch phase {
        case let .failed(message):
            return message
        case let .ready(export) where !export.takesMissing.isEmpty:
            let count = export.takesMissing.count
            return "\(count) recording\(count == 1 ? "'s" : "s'") audio was missing from this device, "
                + "so it isn't in the file. Everything written about \(count == 1 ? "it" : "them") is."
        default:
            return "A zip holding practice.json — your songs, loops, markers, exercises, chords, "
                + "routines, goals, journal and practice history — plus your recordings. Keep it "
                + "somewhere safe: Restore, below, reads one back in. A take recorded next to a "
                + "playing song may have picked that song up through the mic."
        }
    }

    /// Recordings dominate; everything a player has ever written is small beside one take. So the
    /// figure is the recordings' size, and it is stated as an approximation because the zip's
    /// compression is not predictable from the inputs.
    private var estimatedBytes: Int64 { includesRecordings ? usage.takeBytes : 0 }

    private func measure() async {
        usage = await Task.detached(priority: .utility) { StorageUsage.measure() }.value
    }

    /// Read on the main actor, write off it.
    ///
    /// `ArchiveSource.everything` and `snapshot` are `@MainActor` because a `@Model` is not
    /// `Sendable`; what `snapshot` returns is a plain value, so encoding, staging and zipping —
    /// which is all of the expensive work — happen on a detached task.
    private func prepare() async {
        discard()
        phase = .preparing
        do {
            let archive = ArchiveBuilder.snapshot(
                from: try ArchiveSource.everything(in: context),
                appVersion: SupportDiagnostics.currentAppVersion(bundle: Bundle.main),
                includesTakeAudio: includesRecordings
            )
            let takesDirectory = includesRecordings ? try? RecordingStore.directory() : nil
            // Not behind the recordings switch: reference pictures are capped and few, and they are
            // the player's own material rather than the bulk that switch exists to control.
            let attachmentsDirectory = try? ReferenceAttachmentStore.directory()
            phase = .ready(try await Task.detached(priority: .userInitiated) {
                try ArchiveWriter.write(archive, takesDirectory: takesDirectory,
                                        attachmentsDirectory: attachmentsDirectory)
            }.value)
        } catch {
            phase = .failed("Couldn't prepare a copy — \(error.localizedDescription)")
        }
    }

    /// Throw away a prepared archive. Safe to call in any phase.
    private func discard() {
        if case let .ready(export) = phase { ArchiveWriter.cleanUp(export) }
        phase = .idle
    }
}

#Preview {
    Form { ExportSection() }
        .modelContainer(for: Song.self, inMemory: true)
}
