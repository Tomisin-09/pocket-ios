import SwiftUI

/// A dimmed, centred card shown while a single song is read (ADR 0011 Slice 2), and while a song shared
/// in from another app is (ADR 0273). Decoding takes a beat, so this reassures the user the app is
/// working and blocks re-triggering the picker mid-import. Several files read under the import sheet
/// instead, which lists them (ADR 0290).
///
/// **Opaque, and naming the file** (2026-11-03, item 5a of the last push before 1.4). The card used to
/// be `surfaceStandard`, ink at 9%, so the screen behind showed through it and the words sat on
/// whatever was there. And it counted files *done*, so a single long decode read "Importing 0 of 1…"
/// throughout and looked stuck. It now draws on the app's own background, and says which song it is on.
struct ImportProgressOverlay: View {
    let progress: SongImportProgress

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 10) {
                ProgressView()
                    .tint(PocketColor.active)
                    .padding(.bottom, 4)
                Text(progress.headline)
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if let position = progress.position {
                    Text(position)
                        .font(.pocketMono(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                        .monospacedDigit()
                }
            }
            .padding(24)
            .frame(maxWidth: 280)
            .background(PocketColor.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(PocketColor.surfaceBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([progress.headline, progress.position].compactMap { $0 }.joined(separator: ", "))
    }
}

extension View {
    /// The shared import feedback: the card while one file is read, and the import sheet (ADR 0290) for
    /// several, or for one that was skipped. Both the home hub and the library attach this, at the body
    /// root, so importing behaves identically from either **+** button (a picker-level failure still
    /// surfaces through each screen's own "Couldn't import" alert).
    ///
    /// - Parameters:
    ///   - open: a song tapped in the sheet, called once the sheet has gone, since a push can't start
    ///     under a sheet.
    ///   - afterBatch: the sheet closed with *Done* after at least one song was added.
    func songImportFeedback(_ model: SongImportModel, open: @escaping (Song) -> Void,
                            afterBatch: @escaping () -> Void = {}) -> some View {
        sheet(isPresented: Binding(get: { model.showingSheet }, set: { model.showingSheet = $0 }),
              onDismiss: {
                  if let song = model.takeOpening() {
                      open(song)
                  } else if (model.lastOutcome?.imported ?? 0) > 0 {
                      afterBatch()
                  }
              },
              content: {
                  if let batch = model.batch { SongImportSheet(batch: batch, onOpen: model.open) }
              })
        .overlay { if let progress = model.progress { ImportProgressOverlay(progress: progress) } }
    }
}

#Preview {
    ImportProgressOverlay(progress: SongImportProgress(completed: 1, total: 5, current: "Binta"))
}
