import SwiftUI

/// One journal entry, **self-describing** by owner: a loop entry shows its mastery + command-tempo
/// percent; an exercise entry shows its command BPM. Keyed off `entry.exercise` so the two snapshots
/// are never rendered in the wrong units (ADR 0058).
///
/// Shared by the per-owner `JournalSheet` (where the owner is implicit, so `ownerLabel` is `nil`) and
/// the aggregated **Journal space** (`JournalTabView`, which passes an owner caption so an entry in a
/// mixed list still says what it's about).
struct JournalEntryRow: View {
    let entry: JournalEntry
    /// Owner attribution shown above the snapshot — set only in the aggregated feed; pass `nil` in
    /// the per-owner sheet, where the owner is already the sheet's subject.
    var ownerLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                KindChip(kind: entry.kind)
                Spacer(minLength: 0)
                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.pocketMono(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Text(entry.text)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textPrimary)
            if let ownerLabel {
                Text(ownerLabel)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.journal)
                    .lineLimit(1)
            }
            snapshot
        }
        .padding(.vertical, 2)
    }

    /// The immutable context snapshot — where the owner's achievement stood at write time. A **loop**
    /// entry with neither a mastery nor a measured command tempo has nothing to show, so its row is
    /// omitted rather than rendered as a dangling `— · —`; when *either* is present the pair still
    /// renders (keeping the ADR-0039 "unrated"/"not measured" signal, e.g. `— · 90%`).
    @ViewBuilder private var snapshot: some View {
        if entry.exercise != nil {
            Text(JournalSheet.bpmLabel(entry.commandBpmAtEntry,
                                       notesPerBeat: entry.commandNotesPerBeatAtEntry))
                .font(.pocketMono(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        } else if entry.masteryAtEntry != nil || entry.commandTempoAtEntry != nil {
            HStack(spacing: 8) {
                MasteryReadout(mastery: entry.masteryAtEntry)
                Text("· \(LoopProgressFormat.percentLabel(entry.commandTempoAtEntry))")
                    .font(.pocketMono(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
    }
}

/// A small coloured pill for an entry's kind — emoji + label. The colour mapping lives here
/// (presentation), keeping `EntryKind` itself UI-free and unit-testable.
struct KindChip: View {
    let kind: EntryKind

    var body: some View {
        Text("\(kind.emoji)  \(kind.label)")
            .font(.futura(.caption, weight: .semibold))
            .foregroundStyle(Self.tint(for: kind))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Self.tint(for: kind).opacity(0.16)))
    }

    /// The kind's accent colour — the single source of truth, reused by the completion-screen tag
    /// selector (`RoutineBlockDoneView`) so a chip reads the same everywhere.
    static func tint(for kind: EntryKind) -> Color {
        switch kind {
        case .goal: return .blue
        case .breakthrough: return PocketColor.active
        case .struggle: return .orange
        case .note: return PocketColor.textSecondary
        case .session: return .purple
        case .ear: return PocketColor.journal   // 👂 ear-training note (ADR 0104)
        case .improvise: return PocketColor.practice   // 🎸 jam note over a backing loop (ADR 0135)
        }
    }
}
