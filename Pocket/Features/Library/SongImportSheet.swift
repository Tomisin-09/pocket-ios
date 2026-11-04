import SwiftUI

/// **The import sheet** (ADR 0290): every file picked, as it's read. Each row says where its file is
/// (*Waiting*, *Reading the file…*, *Added*) or why it was skipped, and a song that was added opens from
/// its row. It replaces the card and the alert after it for a batch. The rows come from `SongImportBatch`,
/// so the sheet holds no state of its own.
///
/// It can't be swiped away while files are still being read, which keeps the picker from being opened
/// again halfway through, as the card did. *Done* appears once they all are.
struct SongImportSheet: View {
    let batch: SongImportBatch
    /// An added file's row tapped: open its song.
    let onOpen: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(batch.files) { file in
                        row(file).listRowBackground(PocketColor.surfaceStandard)
                    }
                } footer: {
                    if batch.isFinished, batch.summary.imported > 0 {
                        Text(batch.summary.imported == 1 ? "Tap the song to open it." : "Tap a song to open it.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle(batch.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if batch.isFinished {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(!batch.isFinished)
        .onChange(of: batch.isFinished) { _, finished in
            guard finished else { return }
            AccessibilityNotification.Announcement(batch.summary.message).post()
        }
    }

    @ViewBuilder private func row(_ file: SongImportBatch.File) -> some View {
        if file.state == .added {
            Button { onOpen(file.id) } label: { rowContent(file) }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the song")
        } else {
            rowContent(file)
        }
    }

    private func rowContent(_ file: SongImportBatch.File) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            icon(file.state)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                    .lineLimit(2)
                Text(Self.line(file.state))
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Spacer(minLength: 0)
            if file.state == .added {
                Image(systemName: "chevron.right")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func icon(_ state: SongImportBatch.State) -> some View {
        switch state {
        case .waiting:
            Image(systemName: "circle.dotted").foregroundStyle(PocketColor.textSecondary)
        case .reading:
            ProgressView().tint(PocketColor.active)
        case .added:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(PocketColor.confirm)
        case .skipped:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(PocketColor.danger)
        }
    }

    /// What a row says under the file's name.
    nonisolated static func line(_ state: SongImportBatch.State) -> String {
        switch state {
        case .waiting: "Waiting"
        case .reading: "Reading the file…"
        case .added: "Added"
        case .skipped(let reason): reason
        }
    }
}

#Preview {
    var batch = SongImportBatch(names: ["Binta", "take-3-final", "Little Wing", "Voice memo 14"])
    batch.added(0)
    batch.skipped(1, because: WaveformExtractor.ExtractError.emptyFile)
    batch.reading(2)
    return SongImportSheet(batch: batch, onOpen: { _ in })
}
