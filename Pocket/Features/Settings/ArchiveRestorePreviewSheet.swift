import SwiftUI

/// What an archive holds, shown **before** any of it lands (ADR 0188 D9).
///
/// D9's argument applies to this door in a different way than to the receive door. A shared routine is
/// one unit and its summary is small enough to read whole; an archive is the player's whole library,
/// so the summary is a count per kind — enough to recognise *which* archive this is and what it will
/// add, which is what a player about to restore actually needs to decide.
///
/// Every number here is read off `RestorePlan`, which is the same value the writer consumes. If the
/// sheet counted the payload and the writer walked the records, the summary would be a second opinion
/// rather than a promise.
struct ArchiveRestorePreviewSheet: View {
    let pending: PendingRestore
    /// Write it. The sheet does not own the store.
    let onRestore: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var plan: RestorePlan { pending.plan }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if plan.lines.isEmpty {
                        Text("This archive is empty.")
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textSecondary)
                            .listRowBackground(PocketColor.background)
                    }
                    ForEach(plan.lines) { line in
                        tallyRow(line)
                    }
                } header: {
                    Text("From this copy")
                } footer: {
                    Text(provenance)
                }

                if !notes.isEmpty {
                    Section {
                        ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                            Label(note, systemImage: "info.circle")
                                .font(.futura(.body))
                                .foregroundStyle(PocketColor.textSecondary)
                                .listRowBackground(PocketColor.background)
                        }
                    } header: {
                        Text("Worth knowing")
                    }
                }
            }
            .settingsScreen(title: "Restore")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Restore") {
                        onRestore()
                        dismiss()
                    }
                    .disabled(plan.isEmpty)
                }
            }
        }
    }

    /// One kind, and what will happen to it.
    ///
    /// The already-present count is shown rather than subtracted away, because "8 of these 40 are
    /// already here" is the sentence that explains why the number that lands is smaller than the
    /// number in the file — and without it a player would reasonably think a restore had failed.
    @ViewBuilder
    private func tallyRow(_ line: RestorePlan.Line) -> some View {
        LabeledContent(line.kind.label) {
            if line.alreadyPresent > 0 && line.landing > 0 {
                Text("\(line.landing) new · \(line.alreadyPresent) already here")
                    .foregroundStyle(PocketColor.textSecondary)
            } else if line.landing == 0 {
                Text("all \(line.alreadyPresent) already here")
                    .foregroundStyle(PocketColor.textSecondary)
            } else {
                Text("\(line.landing)")
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .font(.futura(.body))
        .listRowBackground(PocketColor.background)
    }

    /// Which archive this is. The date and the build that wrote it are what tell two exports apart,
    /// and an archive that cannot say when it is from is hard to trust against a newer one.
    private var provenance: String {
        "Exported from Red Moon \(pending.read.archive.appVersion) on "
            + pending.read.archive.exportedAt.formatted(date: .abbreviated, time: .shortened)
            + ". Nothing in your library is changed or replaced — anything already here is left alone."
    }

    /// The things a restore cannot put back, said before rather than discovered after.
    ///
    /// Each line appears only when it is true of *this* archive. A list of caveats that do not apply
    /// would make every restore look lossy, which is the opposite of what this screen is for.
    private var notes: [String] {
        var notes: [String] = []
        if plan.songsNeedingRelink > 0 {
            let count = plan.songsNeedingRelink
            notes.append("\(count) song\(count == 1 ? "" : "s") will need pointing at your audio "
                         + "again — loops, markers and notes come back, the files themselves were "
                         + "never in the archive.")
        }
        if plan.takeAudioMissing > 0 {
            let count = plan.takeAudioMissing
            notes.append("\(count) recording\(count == 1 ? "" : "s") had no audio in this archive. "
                         + "Everything written about \(count == 1 ? "it" : "them") still comes back.")
        }
        return notes
    }
}
