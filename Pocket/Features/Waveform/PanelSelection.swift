import Foundation

/// Multi-select state for a waveform reference panel — the loops list and the markers
/// list (ADR 0125). Pure value state (no SwiftUI, no SwiftData) so the mode's rules —
/// what a hold seeds, what Select all means when everything is already selected, what
/// happens when rows disappear underneath a live selection — are unit-testable.
///
/// Deliberately keyed by `uid`, not `persistentModelID`: a freshly punched loop's
/// persistent id flips on the first autosave (ADR 0090), which would silently drop it
/// out of a selection made moments earlier.
struct PanelSelection: Equatable {

    /// True while the panel is in selection mode — rows show selection circles, the
    /// per-row controls hide, and the header carries the bulk actions.
    private(set) var isActive = false

    /// The selected rows' stable `uid`s. Only meaningful while `isActive`.
    private(set) var ids: Set<UUID> = []

    var count: Int { ids.count }
    var isEmpty: Bool { ids.isEmpty }

    func contains(_ id: UUID) -> Bool { ids.contains(id) }

    /// Enter selection mode, with nothing selected. The way in is a hold on the panel
    /// **header**, not on a row: a row's hold already opens its edit sheet (ADR 0028), and
    /// that's the gesture people use to rename a loop.
    mutating func begin() {
        isActive = true
        ids = []
    }

    /// Tap a row while selecting — add it, or take it back out.
    mutating func toggle(_ id: UUID) {
        guard isActive else { return }
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
    }

    /// The header's Select-all control, which is really a **toggle**: it selects
    /// everything, unless everything already is, in which case it clears. That's the
    /// standard behaviour and it saves a second control for "none".
    mutating func toggleAll(of all: [UUID]) {
        guard isActive else { return }
        ids = ids.count == all.count ? [] : Set(all)
    }

    /// Whether `toggleAll` would currently clear rather than select — drives the
    /// control's title so it never lies about what it's about to do.
    func allSelected(of all: [UUID]) -> Bool {
        !all.isEmpty && ids.count == all.count
    }

    /// Leave selection mode (Done, or the last row went away).
    mutating func end() {
        isActive = false
        ids = []
    }

    /// Drop ids whose rows no longer exist — a bulk delete removes the very rows that
    /// were selected, and a stale id would keep "3 selected" on screen over two rows.
    /// An emptied list ends the mode outright: there is nothing left to select, so the
    /// selection header would be a dead end.
    mutating func reconcile(with existing: [UUID]) {
        guard isActive else { return }
        if existing.isEmpty { end(); return }
        ids.formIntersection(existing)
    }

    /// The selection header's title. Zero selected is the honest prompt ("Select loops"),
    /// not "0 selected" — the mode has just opened and nothing has been chosen yet.
    static func title(count: Int, noun: String, plural: String) -> String {
        switch count {
        case 0: return "Select \(plural)"
        case 1: return "1 \(noun) selected"
        default: return "\(count) \(plural) selected"
        }
    }
}
