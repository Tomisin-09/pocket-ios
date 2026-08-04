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
    /// 1-based position in the routine, shown as a leading number so the sequence is clear at a
    /// glance (ADR 0071). `nil` hides it (e.g. contexts that don't want numbering).
    var number: Int?
    /// Whether to show the read-only `×N` repeat badge (ADR 0076). The editor turns it off because it
    /// shows its own always-visible, tappable `×N` **chip** in the same slot instead.
    var showsRepsBadge: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            if let number {
                Text("\(number)")
                    .font(.pocketMono(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
                    .frame(minWidth: 18, alignment: .trailing)
            }
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
            if showsReps {
                Text("×\(item.effectiveReps)")
                    .font(.pocketMono(.caption))
                    .foregroundStyle(PocketColor.practice)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(PocketColor.practiceCircleWash))
                    .accessibilityLabel("Repeats \(item.effectiveReps) times")
            }
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

    /// Whether to badge the repeat count — a real unit block set to run more than once (ADR 0076).
    /// Rests and orphans never repeat; a single run needs no badge; and the editor suppresses it
    /// (`showsRepsBadge`) in favour of its own tappable chip.
    private var showsReps: Bool {
        showsRepsBadge && item.kind != .rest && !item.isOrphaned && item.effectiveReps > 1
    }

    private var symbolName: String {
        if item.kind == .rest { return "pause.fill" }
        if item.isOrphaned { return "questionmark" }
        if let exercise = item.exercise { return exercise.template.iconName }
        // A loop block carries a mode (ADR 0104 Slice 2): ear training reads with the ear glyph.
        // A loop block carries a mode (ADR 0104 / 0135): each draws its own glyph, from the mode.
        if item.loop != nil {
            return item.loopRunMode == .trainer ? "repeat" : item.loopRunMode.symbolName
        }
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
            // Empty for a freeform block with no click — nil so the row drops the line entirely.
            let label = exercise.commandProgressLabel
            return label.isEmpty ? nil : label
        }
        if let loop = item.loop {
            // A non-trainer block names its mode; a standard trainer block just names its song
            // (ADR 0104 / 0135), since the trainer is what a loop block has always meant.
            guard item.loopRunMode == .trainer else {
                let mode = item.loopRunMode.label
                return loop.song.map { "\(mode) · \($0.title)" } ?? mode
            }
            return loop.song?.title
        }
        if let song = item.song {
            return song.artist.isEmpty ? "Play-along" : song.artist
        }
        return nil
    }
}
