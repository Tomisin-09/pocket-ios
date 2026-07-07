import SwiftUI

/// One block in the routine editor (ADR 0066, slice 2): a kind badge plus the referenced
/// unit's title and progress line, or a plain "Rest" / "Unit removed" for a rest or an
/// orphaned block. Read-only display; the editor owns reorder/delete/kind changes.
struct RoutineItemRow: View {
    let item: RoutineItem

    var body: some View {
        HStack(spacing: 12) {
            kindBadge
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.futura(.body))
                    .foregroundStyle(item.isOrphaned ? PocketColor.textSecondary
                                                      : PocketColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.futura(.caption))
                        .foregroundStyle(item.isOrphaned ? PocketColor.textSecondary
                                                          : PocketColor.practice)
                }
            }
            Spacer(minLength: 4)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.kind.displayName). \(title). \(subtitle ?? "")")
    }

    /// A small pill naming the block kind — the routine's structural rhythm at a glance.
    private var kindBadge: some View {
        Text(item.kind.displayName.uppercased())
            .font(.futura(.caption2, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(item.kind == .rest ? PocketColor.textSecondary
                                                : PocketColor.practice)
            .frame(width: 62)
            .padding(.vertical, 5)
            .background(Capsule().fill(item.kind == .rest ? PocketColor.barPlayed
                                                          : PocketColor.practiceCircleWash))
    }

    /// The block's headline: the unit's name, "Rest", or an orphaned marker.
    private var title: String {
        if item.kind == .rest { return "Rest" }
        if item.isOrphaned { return "Unit removed" }
        if let exercise = item.exercise {
            return exercise.name.isEmpty ? "Untitled exercise" : exercise.name
        }
        if let loop = item.loop {
            return loop.name.isEmpty ? "Untitled loop" : loop.name
        }
        if let song = item.song {
            return song.title.isEmpty ? "Untitled song" : song.title
        }
        return "Unit removed"
    }

    /// The block's supporting line — the unit's command→reach, its song, or a rest hint.
    private var subtitle: String? {
        if item.kind == .rest { return "Breather" }
        if item.isOrphaned { return "Skipped — the unit was deleted" }
        if let exercise = item.exercise {
            return "Command \(exercise.command) → \(exercise.derivedTarget) BPM"
        }
        if let loop = item.loop {
            return loop.song?.title
        }
        return nil
    }
}
