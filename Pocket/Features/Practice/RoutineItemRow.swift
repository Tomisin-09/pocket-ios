import SwiftUI

/// One block in the routine editor (ADR 0066, slice 2): a type icon plus the referenced
/// unit's title and progress line — or a plain "Rest" / "Unit removed" for a rest or an
/// orphaned block. Read-only display; the editor owns reorder/delete.
///
/// Blocks carry no user-editable *kind* (Focus/Warm-up/Play) in the manual editor — every
/// unit block is focused work and rests are authored separately, so there's no
/// category-picker to juggle across two entity types (that collided with the exercise
/// template names, e.g. a "Warm-up" template vs a warm-up block).
struct RoutineItemRow: View {
    let item: RoutineItem

    var body: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.futura(.body))
                    .foregroundStyle(item.isOrphaned ? PocketColor.textSecondary
                                                      : PocketColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.futura(.caption))
                        .foregroundStyle(item.isOrphaned || item.kind == .rest
                                         ? PocketColor.textSecondary : PocketColor.practice)
                }
            }
            Spacer(minLength: 4)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle ?? "")")
    }

    /// A small type glyph — the exercise's template icon, a loop/rest symbol — washed in the
    /// practice tint (a rest is muted). Keeps the routine's rhythm scannable at a glance.
    private var icon: some View {
        Image(systemName: symbolName)
            .font(.futura(.body))
            .foregroundStyle(item.kind == .rest || item.isOrphaned
                             ? PocketColor.textSecondary : PocketColor.practice)
            .frame(width: 34, height: 34)
            .background(Circle().fill(item.kind == .rest || item.isOrphaned
                                      ? PocketColor.barPlayed : PocketColor.practiceCircleWash))
    }

    private var symbolName: String {
        if item.kind == .rest { return "pause.fill" }
        if item.isOrphaned { return "questionmark" }
        if let exercise = item.exercise { return exercise.template.iconName }
        if item.loop != nil { return "repeat" }
        if item.song != nil { return "music.note" }
        return "questionmark"
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
