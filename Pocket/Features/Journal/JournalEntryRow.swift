import SwiftUI

/// One journal entry, **self-describing** by owner: a loop entry shows its mastery + command-tempo
/// percent; an exercise entry shows its command BPM; a session entry (ADR 0143) shows the units it
/// was made of. Keyed off `entry.ownerKind` so a snapshot is never rendered in the wrong units — a
/// hand-written `entry.exercise != nil` used to decide this, which was only ever right while there
/// were exactly two owners (ADR 0058 / 0143).
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
    /// The tap action for one of a **session** entry's practised-unit pills (ADR 0143), or `nil` for
    /// a unit that no longer resolves. The default sends every pill to plain text, which is right for
    /// the per-owner sheet: it never shows session entries, since they belong to no unit.
    var openUnit: (SessionUnitRef) -> (() -> Void)? = { _ in nil }

    /// Whether the note is showing in full. **Expanding happens in place**, because ADR 0142 J5
    /// refused a journal-entry detail screen — *"a second place to read one entry"* — and a session
    /// or standalone note has no owner screen to be the honest destination instead. Row-local, so it
    /// resets when the feed changes underneath it, which is the right behaviour for a reading aid.
    @State private var expanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            JournalKindRail(tint: KindChip.tint(for: entry.kind))
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    // Emoji **and word** (ADR 0207 D1, amended 2026-09-09). The first build showed
                    // the glyph alone on the reasoning that the rail already carried the kind in
                    // colour; on device that turned out to be wrong. A colour is *learned* and a
                    // glyph at caption size is *guessed* — 🎯 against 🧗 at 11pt is not a reliable
                    // read — whereas the word is simply known on sight, by everyone, immediately.
                    //
                    // Plain tinted text, **not** the `KindChip` capsule: the rail is already spending
                    // this kind's colour two points to the left, and a filled pill beside it would be
                    // accent-on-accent — the class of defect that survives a green build.
                    Text(entry.kind.emoji)
                        .font(.futura(.caption))
                        // Hidden, or VoiceOver reads the kind twice: the label beside it is the
                        // same word, now actually on screen.
                        .accessibilityHidden(true)
                    Text(entry.kind.label)
                        .font(.futura(.caption, weight: .semibold))
                        .foregroundStyle(KindChip.tint(for: entry.kind))
                    Spacer(minLength: 0)
                    // The pin's *state*, so it is legible without opening the hold menu that sets it
                    // (ADR 0190 D3). Beside the time rather than in the row's leading edge: it is a
                    // property of the record, not a control, and nothing here is tappable.
                    if entry.isPinned { PinnedGlyph() }
                    Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.pocketMono(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Text(entry.text)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                    // Clamped, or one long session note fills the screen and the feed stops being a
                    // feed. Four lines is enough to tell entries apart, which is what scrolling past
                    // them is for.
                    .lineLimit(expanded ? nil : Self.collapsedLineLimit)
                    // A plain gesture, **not** a `Button`: the feed's rows carry a `contextMenu`, and
                    // a button inside one fires on both the tap and the hold.
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { expanded.toggle() } }
                    // **A named action, never `.isButton`.** The trait would retype this element
                    // from `staticText` to `button` — which misreports a note as a control to
                    // VoiceOver, and broke `RowUndoUITests` outright, since the feed's rows are
                    // found by `cells.containing(.staticText, identifier:)`. The note is content
                    // that happens to expand; the action carries the affordance without the lie.
                    .accessibilityAction(named: expanded ? "Collapse note" : "Show whole note") {
                        expanded.toggle()
                    }
                if let ownerLabel {
                    JournalOwnerCaption(label: ownerLabel, onOpen: onOpenOwner)
                }
                snapshot
            }
        }
        .padding(.vertical, 6)
    }

    /// Four. Enough to tell one entry from another while scrolling; short enough that a long session
    /// note cannot take the screen.
    private static let collapsedLineLimit = 4

    /// The immutable context snapshot — where the owner's achievement stood at write time. A **loop**
    /// entry with neither a mastery nor a measured command tempo has nothing to show, so its row is
    /// omitted rather than rendered as a dangling `— · —`; when *either* is present the pair still
    /// renders (keeping the ADR-0039 "unrated"/"not measured" signal, e.g. `— · 90%`).
    ///
    /// A **session** entry (ADR 0143) has no tempo of its own — it spans several units at several
    /// tempos — so what it snapshotted is *what was practised*, and that is what renders here. An
    /// **orphan** (owner deleted, relationship nullified) shows nothing at all.
    @ViewBuilder private var snapshot: some View {
        switch entry.ownerKind {
        case .exercise:
            HStack(spacing: 8) {
                Text(JournalSheet.bpmLabel(entry.commandBpmAtEntry,
                                           notesPerBeat: entry.commandNotesPerBeatAtEntry))
                    .font(.pocketMono(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                // An exercise entry has snapshotted its mastery since ADR 0169 and the feed has
                // never drawn it — only the editor's Snapshot section did. Rendered **only when
                // present**, unlike the loop branch's paired readout: ADR 0169 deliberately did not
                // back-fill, so an unconditional `MasteryReadout` would hang an em-dash off every
                // entry written before it shipped.
                if entry.masteryAtEntry != nil {
                    MasteryReadout(mastery: entry.masteryAtEntry)
                }
            }
        case .loop:
            if entry.masteryAtEntry != nil || entry.commandTempoAtEntry != nil {
                HStack(spacing: 8) {
                    MasteryReadout(mastery: entry.masteryAtEntry)
                    Text("· \(LoopProgressFormat.percentLabel(entry.commandTempoAtEntry))")
                        .font(.pocketMono(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
        case .session:
            SessionUnitChips(units: entry.practisedUnits, openAction: openUnit)
        case .metronome:
            // The click that was running (ADR 0160) — "96 BPM · 4/4 · ♫ · gentle withdrawal", in the
            // same mono caption an exercise's BPM uses. Nothing renders if the columns are missing,
            // which only an entry written by a future bug could manage.
            if let sitting = entry.metronomeContext {
                Text(sitting.summary)
                    .font(.pocketMono(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        case .standalone, .orphan:
            // Two different meanings, one rendering, and deliberately so (ADR 0155 §2): a standalone
            // note never had a subject and an orphan *lost* one, but neither has anything to
            // snapshot. They share a branch, not an identity — the store can still tell them apart
            // the moment either wants its own treatment.
            EmptyView()
        }
    }
}

/// The **owner attribution** under a feed item — "Slow Bend · Verse riff", "Spider · exercise".
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

/// The **leading colour rail** on a feed row — 3pt, full height, tinted by what the row is.
///
/// It replaces the leading `KindChip` on the feed (not in the composer, where the chip is the
/// control). Three things the chip could not do: it carried the kind's *word*, which is the widest
/// thing on a row and the least informative; it sat in the reading path, so the words you came for
/// were the third thing you saw; and it was grey for `.note`, which is the plurality (ADR 0190 D5).
/// A rail says the same thing in the periphery and gives the text back its lead.
///
/// The idiom is `SongCard`'s, which has drawn a leading accent bar tinted by mastery tier since
/// ADR 0062 — so this reads as the app's existing vocabulary rather than a new one.
///
/// Shared by both feed rows: notes tint by `EntryKind`, takes by `PocketColor.journal`. The Journal
/// space's premise is one feed (ADR 0100), so the two row kinds must draw the same silhouette
/// (ADR 0190 D2's reasoning, applied to shape rather than to a verb).
struct JournalKindRail: View {
    let tint: Color

    var body: some View {
        // Greedy in height by default, which is what makes it span whatever the row's content
        // turns out to be — including a note the reader has just expanded.
        RoundedRectangle(cornerRadius: 1.5)
            .fill(tint)
            .frame(width: 3)
            // The rail is decoration for a state the row already states in words and glyphs.
            .accessibilityHidden(true)
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
