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
    /// Open the owner (ADR 0142). `nil` leaves the caption as plain text — which is what the
    /// per-owner sheet wants, and what an item with nowhere honest to go gets (`JournalOwnerRoute`).
    var onOpenOwner: (() -> Void)?

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
                JournalOwnerCaption(label: ownerLabel, onOpen: onOpenOwner)
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

/// The **owner attribution** under a feed item — "Little Wing · Verse riff", "Spider · exercise".
/// A link when the owner has somewhere to go (ADR 0142), plain text otherwise, so the affordance is
/// never a promise the tap can't keep.
///
/// A `Button` rather than a `NavigationLink`: the feed's rows are not themselves links, and the whole
/// row shouldn't become tappable just because part of it is. The chevron is what tells you the
/// difference between the two states at a glance.
struct JournalOwnerCaption: View {
    let label: String
    let onOpen: (() -> Void)?

    var body: some View {
        if let onOpen {
            Button {
                onOpen()
                haptic(.light)
            } label: {
                HStack(spacing: 3) {
                    Text(label).lineLimit(1)
                    Image(systemName: "chevron.forward")
                        .font(.futura(.caption2, weight: .semibold))
                }
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.journal)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(label)")
            .accessibilityAddTraits(.isLink)
        } else {
            Text(label)
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.journal)
                .lineLimit(1)
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
