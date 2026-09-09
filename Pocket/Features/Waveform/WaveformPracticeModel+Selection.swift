import SwiftUI

/// Multi-select on the loops and markers panels (ADR 0125): the seams the panels bind to,
/// and the bulk actions the selection header fires. The selection *rules* are pure
/// (`PanelSelection`) and the *edits* are pure (`LoopBulkEdit`); what lives here is the
/// wiring between them and the model's SwiftData objects.
extension WaveformPracticeModel {

    // MARK: The panels' seams

    var loopSelectionSeam: PanelSelectionSeam {
        PanelSelectionSeam(selection: loopSelection,
                           begin: { self.beginLoopSelection() },
                           toggle: { uid in
                               self.loopSelection.toggle(uid)
                               haptic(.light)   // the tap's own confirmation, as on a Photos cell
                           },
                           toggleAll: { self.loopSelection.toggleAll(of: self.loops.map(\.uid)) },
                           end: { self.loopSelection.end() },
                           delete: { self.deleteSelectedLoops() })
    }

    var markerSelectionSeam: PanelSelectionSeam {
        PanelSelectionSeam(selection: markerSelection,
                           begin: { self.beginMarkerSelection() },
                           toggle: { uid in
                               self.markerSelection.toggle(uid)
                               haptic(.light)
                           },
                           toggleAll: { self.markerSelection.toggleAll(of: self.markers.map(\.uid)) },
                           end: { self.markerSelection.end() },
                           delete: { self.deleteSelectedMarkers() })
    }

    /// The snags panel's seam (ADR 0206 D2). Delete-only, like the markers one — a snag has nothing
    /// to rename, recolour or rate, which is what ADR 0202 D2 said when it declined an edit sheet.
    var snagSelectionSeam: PanelSelectionSeam {
        PanelSelectionSeam(selection: snagSelection,
                           begin: { self.beginSnagSelection() },
                           toggle: { uid in
                               self.snagSelection.toggle(uid)
                               haptic(.light)
                           },
                           toggleAll: { self.snagSelection.toggleAll(of: self.snagsByTime.map(\.uid)) },
                           end: { self.snagSelection.end() },
                           delete: { self.deleteSelectedSnags() })
    }

    /// Only one panel selects at a time. Two live selections would put two selection
    /// headers and two sets of bulk actions on screen with no way to tell which Delete
    /// you're about to hit — and there is no bulk action that spans both kinds.
    private func beginLoopSelection() {
        markerSelection.end()
        snagSelection.end()
        loopSelection.begin()
    }

    private func beginMarkerSelection() {
        loopSelection.end()
        snagSelection.end()
        markerSelection.begin()
    }

    /// Internal rather than private: `selectSnagsInActiveLoop` enters the mode on the player's
    /// behalf, and it lives in `+Snags.swift` where the rest of the marks' behaviour is.
    func beginSnagSelection() {
        loopSelection.end()
        markerSelection.end()
        snagSelection.begin()
    }

    // MARK: What's selected

    var selectedLoops: [Loop] { loops.filter { loopSelection.contains($0.uid) } }
    var selectedMarkers: [Marker] { markers.filter { markerSelection.contains($0.uid) } }
    var selectedSnags: [Snag] { snagsByTime.filter { snagSelection.contains($0.uid) } }

    // MARK: Bulk actions

    /// Which way the header's star will go — add unless every selected loop is already
    /// favourited, so a mixed selection never silently unstars anything (ADR 0119).
    var bulkFavoriteAdds: Bool { LoopSelectionSummary.favoriteAction(for: selectedLoops) }

    func favoriteSelectedLoops() {
        let targets = selectedLoops
        guard !targets.isEmpty else { return }
        let favorite = LoopSelectionSummary.favoriteAction(for: targets)
        targets.forEach { $0.isFavorite = favorite }
        haptic(.light)
    }

    /// Apply the bulk sheet's partial edit. Writing straight to the `@Model`s persists
    /// via autosave, like every other loop edit on this screen.
    func applyBulkEdit(_ edit: LoopBulkEdit) {
        let targets = selectedLoops
        guard !targets.isEmpty, !edit.isEmpty else { return }
        targets.forEach(edit.apply(to:))
        haptic(.light)
    }
}
