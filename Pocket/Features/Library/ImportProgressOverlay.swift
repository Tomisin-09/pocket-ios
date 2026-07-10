import SwiftUI

/// A dimmed, centred "Importing N of M…" card shown while a batch song import runs
/// (ADR 0011 Slice 2). Decoding several files takes a beat, so this reassures the
/// user the app is working and blocks re-triggering the picker mid-import.
struct ImportProgressOverlay: View {
    let progress: SongImportProgress

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .tint(PocketColor.active)
                Text("Importing \(progress.completed) of \(progress.total)…")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textPrimary)
                    .monospacedDigit()
            }
            .padding(24)
            .background(PocketColor.surfaceStandard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Importing \(progress.completed) of \(progress.total) songs")
    }
}

extension View {
    /// The shared batch-import feedback: a completion alert (confirms what imported
    /// and lists any skipped files) plus the progress overlay. Both the home hub and
    /// the library attach this so importing behaves identically from either **+**
    /// button (a picker-level failure still surfaces through each screen's own
    /// "Couldn't import" alert).
    func songImportFeedback(_ model: SongImportModel) -> some View {
        alert(model.summary?.title ?? "",
              isPresented: Binding(get: { model.summary != nil },
                                   set: { if !$0 { model.summary = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.summary?.message ?? "")
        }
        .overlay { if let progress = model.progress { ImportProgressOverlay(progress: progress) } }
    }
}

#Preview {
    ImportProgressOverlay(progress: SongImportProgress(completed: 2, total: 5))
}
