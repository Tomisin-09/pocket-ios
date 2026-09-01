import SwiftData
import SwiftUI

/// **Settings ▸ Your data ▸ Storage** — what Red Moon is using, and the two things you can do about
/// it (ADR 0182).
///
/// ADR 0148 §8 said it plainly: owning a player's files means owing them honesty about the space
/// those files take. That debt went unpaid for four months, and while it did, two real leaks ran —
/// a deleted song left its full-size audio behind forever, and the orphan sweep both stores had been
/// carrying since ADR 0069 was **dead code with no production caller**, though the architecture doc
/// described it as though it ran.
///
/// This is the screen that makes the description true, and the arithmetic behind it is
/// `StorageUsage`: pure, injectable, and unit-tested against a throwaway container.
struct StorageSection: View {

    @Environment(\.modelContext) private var context

    @State private var usage: StorageUsage = .none
    @State private var sweeping = false
    @State private var sweepResult: String?

    /// The literal is `AppSettings.songsInBackupDefault`, not `true`, because the value a
    /// `@AppStorage` declares is what SwiftUI uses for an unset key and it does **not** consult the
    /// accessor beside it.
    @AppStorage(AppSettings.Key.songsInBackup)
    private var songsInBackup = AppSettings.songsInBackupDefault

    var body: some View {
        Section {
            ForEach(usage.breakdown, id: \.label) { row in
                LabeledContent(row.label) {
                    Text(StorageUsage.formatted(bytes: row.bytes))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            LabeledContent("Total") {
                Text(StorageUsage.formatted(bytes: usage.total))
                    .foregroundStyle(PocketColor.textPrimary)
            }

            Toggle(isOn: $songsInBackup) {
                FieldInfoLabel(title: "Keep songs in backup", info: SettingsInfo.songsInBackup)
            }
            .onChange(of: songsInBackup) { _, keep in applyBackupExclusion(keeping: keep) }

            if sweeping {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Checking…").foregroundStyle(PocketColor.textSecondary)
                }
            } else {
                Button { reclaim() } label: {
                    FieldInfoLabel(title: "Reclaim space", info: SettingsInfo.reclaimSpace)
                }
            }
        } header: {
            Text("Storage")
        } footer: {
            Text(sweepResult ?? footer)
        }
        .task { await measure() }
    }

    /// Says where the number came from, so it can be compared against the one the system reports
    /// rather than treated as a different app's opinion.
    private var footer: String {
        "Measured now, the same way iPhone Storage measures it. Songs are the copies Red Moon keeps "
            + "so a song plays whether or not the file you imported is still where you found it."
    }

    private func measure() async {
        let storeURL = context.container.configurations.first?.url
        usage = await Task.detached(priority: .utility) {
            StorageUsage.measure(storeURL: storeURL)
        }.value
    }

    /// The **inverse** of the toggle: "keep in backup" on means *not* excluded.
    ///
    /// The written value is read back off the filesystem afterwards rather than assumed, because a
    /// resource-value write can fail quietly and a switch that lies about where a player's audio is
    /// going is worse than one that never moved.
    private func applyBackupExclusion(keeping keep: Bool) {
        try? SongFileStore.setExcludedFromBackup(!keep)
        songsInBackup = !SongFileStore.isExcludedFromBackup()
    }

    /// The referenced sets are built from **every** row of each type, never from one owner's
    /// relationship — a take outlives its loop (ADR 0151) and blocks record takes now too
    /// (ADRs 0179/0180), so a narrower set would classify real recordings as rubbish.
    private func reclaim() {
        sweeping = true
        sweepResult = nil
        do {
            let songs = Set(try context.fetch(FetchDescriptor<Song>()).compactMap(\.audioFileName))
            let takes = Set(try context.fetch(FetchDescriptor<Recording>()).map(\.fileName))
            // Every reference row, filtered in memory — **never** a `#Predicate` on `kindRaw` or on
            // an owner relationship. ADR 0167 says so and `docs/swiftdata-gotchas.md` says why:
            // optional-relationship predicates starve the main thread.
            let images = Set(try context.fetch(FetchDescriptor<ReferenceLink>())
                .map(\.attachmentFileName).filter { !$0.isEmpty })
            Task {
                let outcome = await Task.detached(priority: .userInitiated) {
                    OrphanSweep.run(referencedSongFiles: songs, referencedTakeFiles: takes,
                                    referencedAttachmentFiles: images)
                }.value
                sweepResult = OrphanSweep.summary(outcome)
                await measure()
                sweeping = false
            }
        } catch {
            sweepResult = "Couldn't check for stray files — \(error.localizedDescription)"
            sweeping = false
        }
    }
}

#Preview {
    Form { StorageSection() }
        .modelContainer(for: Song.self, inMemory: true)
}
