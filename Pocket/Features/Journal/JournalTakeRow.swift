import SwiftUI

/// One **take** on the aggregated Journal feed — a play/pause toggle, its owner caption, duration and
/// time. Plays through the shared `RecordingPlayer` (one at a time). Read-only bar the play control,
/// which is the exception the Journal space makes for takes: playing one *is* their nature.
///
/// Lifted out of `JournalTabView` when that file took on the session-entry work (ADR 0143) and ran up
/// against the 400-line cap. It is a row, like its sibling `JournalEntryRow` — which has always lived
/// in its own file.
struct JournalTakeRow: View {
    let take: Recording
    let ownerLabel: String?
    /// Open the take's owner (ADR 0142); `nil` for a song-owned take, which has no run screen.
    let onOpenOwner: (() -> Void)?
    let isPlaying: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.futura(.title))
                    .foregroundStyle(PocketColor.journal)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause take" : "Play take")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    // `displayTitle` falls back to the generic word every take used to be stuck with,
                    // so an unnamed take renders exactly as it always did (ADR 0069 amendment).
                    Text(take.displayTitle)
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textPrimary)
                        .lineLimit(1)
                    Text(take.durationLabel)
                        .font(.pocketMono(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                    Spacer(minLength: 0)
                    Text(take.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.pocketMono(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                if let ownerLabel {
                    JournalOwnerCaption(label: ownerLabel, onOpen: onOpenOwner)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
