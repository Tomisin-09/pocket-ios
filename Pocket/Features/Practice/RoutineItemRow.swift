import SwiftUI

/// One block in the routine editor (ADR 0066, slice 2): a type icon plus the referenced
/// unit's title and progress line — or "Rest" for a rest, and for an orphaned block either
/// the label it arrived with (ADR 0188 S2) or a plain "Unit removed". Read-only display;
/// the editor owns reorder/delete.
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
            if showsRecord {
                Image(systemName: "waveform")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.practice)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(PocketColor.practiceCircleWash))
            }
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
        // `children: .combine` swallows the badges' own labels, so the record state has to be said
        // here or it is invisible to VoiceOver — the badge is the only thing telling these blocks
        // apart in the list.
        .accessibilityLabel("\(title). \(subtitle ?? "")\(showsRecord ? ". Records a take" : "")")
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

    /// Whether to badge this block as **recording** (ADR 0179) — so the routine's block list says
    /// which blocks capture a take without opening each one.
    ///
    /// Unlike `showsReps` this ignores `showsRepsBadge`: the editor replaces the repeat badge with its
    /// own tappable chip, but there is no record chip to replace it with, so suppressing it there
    /// would hide the flag on the one screen where it is set. Reads `RoutineItem.canRecordTake` —
    /// the same rule `RoutineSessionPlayer.stage(for:)` acts on, so a badge and the block it sits on
    /// cannot disagree about whether anything gets recorded (ADR 0180 D2).
    private var showsRecord: Bool {
        item.recordsTake && item.canRecordTake
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
    ///
    /// An orphan that **arrived named** says what it was (ADR 0188 S2 follow-up) — a routine
    /// somebody sent reads *Chorus — Slow Bend*, not *Unit removed*, because the sender's audio
    /// staying on their device is a different fact from a unit having been deleted, and the player
    /// needs the name to know what to put there. The glyph and the muted tint are unchanged, so it
    /// still reads as a block that will not run.
    private var title: String {
        if item.kind == .rest { return "Rest" }
        if item.isOrphaned { return orphanTitle }
        if let exercise = item.exercise {
            return exercise.name.isEmpty ? "Untitled exercise" : exercise.name
        }
        if let loop = item.loop {
            return loop.name.isEmpty ? "Untitled loop" : loop.name
        }
        if let song = item.song {
            return song.title.isEmpty ? "Untitled song" : song.title
        }
        return orphanTitle
    }

    /// The label an orphan block arrived with, or `nil` — trimmed and emptiness-checked in **one**
    /// place, because the title and the caption both branch on it and a whitespace-only label
    /// (this door reads files the app did not write) would otherwise give a row that says *Unit
    /// removed* over a caption claiming it was somebody else's audio.
    private var carriedLabel: String? {
        guard let label = item.orphanLabel?.trimmingCharacters(in: .whitespaces),
              !label.isEmpty else { return nil }
        return label
    }

    /// What an unresolvable block calls itself.
    private var orphanTitle: String { carriedLabel ?? "Unit removed" }

    /// The block's supporting line — the unit's command→reach, its song, or a rest hint.
    private var subtitle: String? {
        if item.kind == .rest { return "Breather" }
        // Two different reasons a block will not run, and the caption is the only place they can be
        // told apart: the unit was deleted here, or it never crossed because it was the sender's own
        // audio (ADR 0188 D4). Both skip; only one is something the player can do anything about.
        if item.isOrphaned {
            return carriedLabel == nil ? "Skipped — the unit was deleted"
                                       : "Skipped — not on this device"
        }
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
