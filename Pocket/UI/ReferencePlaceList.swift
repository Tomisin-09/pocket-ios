import SwiftUI

/// How the place list takes a pick (ADR 0264 D5, D8).
enum ReferencePlacePicking: Equatable {
    /// *Attach to…* in the app: a tap is the save, because the source exists already.
    case onTap
    /// *Save to Red Moon*: a tap marks the place and *Save* writes it, because what's being saved
    /// doesn't exist yet. `nil` is *Keep for later*, which the extension draws itself.
    case held(selected: String?)

    /// Whether `row` is the held pick.
    func isSelected(_ row: ReferenceDestinationPicker.Row) -> Bool? {
        guard case .held(let selected) = self else { return nil }
        return selected == row.id
    }
}

/// **The places a reference can go**, as values (D8): *Recent*, then *Show everything*, a search across
/// all of them, and D6's footer. No store and no model, so the share extension draws the same list from
/// its snapshot (D9), and this file is compiled into both targets (D10).
struct ReferencePlaceList: View {
    let rows: [ReferenceDestinationPicker.Row]
    let standing: PlanStanding
    let onPick: (ReferenceDestinationPicker.Row) -> Void

    @State private var searchText = ""

    var body: some View {
        let found = ReferenceDestinationPicker.matching(rows, searchText)
        Group {
            if rows.isEmpty {
                ReferencePlaceEmpty(standing: standing)
            } else if !searchText.isEmpty && found.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ReferencePlaceSections(rows: rows, standing: standing, searchText: searchText,
                                           picking: .onTap, onPick: onPick)
                }
                .scrollContentBackground(.hidden)
            }
        }
        // Always showing, as drawn: finding one place among many is what the sheet is for.
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: ReferenceDestinationPicker.searchPrompt(for: standing))
    }
}

/// The list's sections, for a `List` that may hold more: what a search finds, or *Recent* and the row
/// that opens everything (everything itself while nothing is recent), then D6's footer.
struct ReferencePlaceSections: View {
    let rows: [ReferenceDestinationPicker.Row]
    let standing: PlanStanding
    let searchText: String
    let picking: ReferencePlacePicking
    let onPick: (ReferenceDestinationPicker.Row) -> Void

    var body: some View {
        let recent = ReferenceDestinationPicker.recent(rows)
        if !searchText.isEmpty {
            Section { places(ReferenceDestinationPicker.matching(rows, searchText)) }
        } else if recent.isEmpty {
            // Nothing practised yet: nothing is recent, so everything is the list.
            ReferencePlaceGroups(rows: rows, picking: picking, onPick: onPick)
        } else {
            Section("Recent") {
                places(recent)
                NavigationLink(ReferenceDestinationPicker.everythingTitle(for: standing)) {
                    ReferencePlaceEverything(rows: rows, standing: standing, picking: picking, onPick: onPick)
                }
                .listRowBackground(PocketColor.surfaceSubtle)
            }
        }
        ReferencePlaceFooter(standing: standing)
    }

    private func places(_ rows: [ReferenceDestinationPicker.Row]) -> some View {
        ForEach(rows) { row in
            ReferencePlaceRow(row: row, selected: picking.isSelected(row)) { onPick(row) }
        }
    }
}

/// Nowhere to attach to yet.
struct ReferencePlaceEmpty: View {
    let standing: PlanStanding

    var body: some View {
        ContentUnavailableView {
            Label("Nowhere to attach it yet", systemImage: "tray")
        } description: {
            Text(standing == .neverBought ? "Songs and loops you add show here."
                                          : "Exercises, routines, songs and loops you make show here.")
        }
    }
}

/// *Show everything*: every place, by kind. A held pick comes back to the screen it was opened from,
/// where *Save* is.
private struct ReferencePlaceEverything: View {
    let rows: [ReferenceDestinationPicker.Row]
    let standing: PlanStanding
    let picking: ReferencePlacePicking
    let onPick: (ReferenceDestinationPicker.Row) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ReferencePlaceGroups(rows: rows, picking: picking) { row in
                onPick(row)
                if picking != .onTap { dismiss() }
            }
            ReferencePlaceFooter(standing: standing)
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(standing == .neverBought ? "Songs and loops" : "Everything")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One section per kind, as `ReferenceDestinationPicker.groups` orders them.
private struct ReferencePlaceGroups: View {
    let rows: [ReferenceDestinationPicker.Row]
    let picking: ReferencePlacePicking
    let onPick: (ReferenceDestinationPicker.Row) -> Void

    var body: some View {
        ForEach(ReferenceDestinationPicker.groups(rows)) { group in
            Section(group.title) {
                ForEach(group.rows) { row in
                    ReferencePlaceRow(row: row, selected: picking.isSelected(row)) { onPick(row) }
                }
            }
        }
    }
}

/// D6's footer, at the foot of the list. Nothing on the plan.
private struct ReferencePlaceFooter: View {
    let standing: PlanStanding

    var body: some View {
        if let footer = ReferenceAttachRules.footer(for: standing) {
            Section {} footer: { Text(footer) }
        }
    }
}

/// One place: its kind's glyph in its home's colour, its name, and its kind, with a lock while it opens
/// only with the plan (D6) or the reason it can't take this source.
///
/// `selected` is the held pick's mark (`ReferencePlacePicking.held`): a ring, filled while chosen.
/// `nil` in the app, where a place the source is already on is ticked instead.
struct ReferencePlaceRow: View {
    let row: ReferenceDestinationPicker.Row
    var selected: Bool?
    let onPick: () -> Void

    var body: some View {
        Button(action: onPick) {
            HStack(spacing: 12) {
                ReferencePlaceGlyph(icon: row.destination.kind.icon, tint: row.destination.kind.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.destination.name)
                        .font(.futura(.body))
                        .foregroundStyle(row.isPickable ? PocketColor.textPrimary : PocketColor.textSecondary)
                    HStack(spacing: 4) {
                        if row.isLocked {
                            Image(systemName: "lock.fill").font(.caption2).accessibilityHidden(true)
                        }
                        Text(row.detail)
                    }
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                }
                Spacer(minLength: 8)
                if let selected, row.isPickable {
                    ReferencePlaceMark(isSelected: selected)
                } else if row.unavailable == ReferenceDestinationPicker.alreadyHere {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!row.isPickable)
        .listRowBackground(PocketColor.surfaceSubtle)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected == true ? .isSelected : [])
    }
}

/// A kind's glyph in a washed circle, as a place row and *Keep for later* draw it.
struct ReferencePlaceGlyph: View {
    let icon: String
    let tint: Color

    var body: some View {
        Circle()
            .fill(tint.opacity(0.18))
            .overlay {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)
    }
}

/// The held pick's mark: an empty ring, or a filled one with a tick, in the screen's tint.
struct ReferencePlaceMark: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(PocketColor.textSecondary))
            .accessibilityHidden(true)
    }
}

extension ReferencePlaceKind {
    /// Each kind's glyph, as the routine editor's add-unit picker draws them.
    var icon: String {
        switch self {
        case .exercise: "metronome"
        case .routine: "list.bullet.rectangle"
        case .song: "music.note"
        case .loop: "repeat"
        }
    }

    /// Each place in its own home's colour: drills and routines are Practice's teal, songs and loops the
    /// Library's terracotta.
    var tint: Color {
        switch self {
        case .exercise, .routine: PocketColor.practice
        case .song, .loop: PocketColor.library
        }
    }
}
