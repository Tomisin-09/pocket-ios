import SwiftUI

/// The bar shown while multi-selecting (ADR 0125), shared by the loops and markers
/// panels so both modes read identically: a select-all circle that matches the row
/// circles, the count, the bulk actions, and Done.
///
/// It is **pinned above the scrolling list**, not carried inside the panel it belongs to
/// (device pass, 2026-07-29): with it in the panel header, selecting a row near the
/// bottom of a long list meant scrolling back up to reach Delete. Pinned, the actions are
/// where they were when the mode opened, however far you scroll.
///
/// The select-all control is the **same glyph the rows use**, one level up — "the circle
/// for all of them." That's why there's no separate "Select all" / "Deselect all" text
/// button: the circle's own filled/empty state already says which way a tap goes.
struct PanelSelectionBar<Actions: View>: View {
    let title: String
    let allSelected: Bool
    let onToggleAll: () -> Void
    let onDone: () -> Void
    /// The bulk actions, in the trailing run before Done. The **last** of these sits in
    /// the chevron's old slot — for loops that's the practice-categories editor.
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onToggleAll) {
                Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                    .font(.futura(.title3))
                    .foregroundStyle(allSelected ? PocketColor.active : PocketColor.textSecondary)
                    .frame(width: 34, height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(allSelected ? "Deselect all" : "Select all")

            Text(title)
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 2)

            actions

            Button(action: onDone) {
                Text("Done")
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.active)
                    .frame(height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done selecting")
        }
        .padding(14)
        .background(panelBackground)
    }
}

/// One bulk action in the selection bar — a glyph with a real touch target, greyed
/// and inert until something is selected, so an empty selection can't fire a delete.
struct PanelActionButton: View {
    let systemImage: String
    let label: String
    var isEnabled: Bool = true
    var tint: Color = PocketColor.textSecondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(isEnabled ? tint : PocketColor.textSecondary.opacity(0.35))
                .frame(width: 36, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}

/// The loops bar: delete · favourite · categories (the chevron's old slot).
struct LoopSelectionBar: View {
    @Bindable var model: WaveformPracticeModel

    var body: some View {
        let seam = model.loopSelectionSeam
        let any = !seam.selection.isEmpty
        PanelSelectionBar(title: PanelSelection.title(count: seam.selection.count,
                                                      noun: "loop", plural: "loops"),
                          allSelected: seam.selection.allSelected(of: model.loops.map(\.uid)),
                          onToggleAll: seam.toggleAll,
                          onDone: seam.end) {
            PanelActionButton(systemImage: "trash", label: "Delete selected loops",
                              isEnabled: any, tint: PocketColor.danger, action: seam.delete)
            // The glyph shows what the tap will *do*: a hollow star adds, a struck one
            // takes the star back off an already-favourited selection (ADR 0119).
            PanelActionButton(systemImage: model.bulkFavoriteAdds ? "star" : "star.slash",
                              label: model.bulkFavoriteAdds
                                  ? "Favourite selected loops"
                                  : "Remove selected loops from favourites",
                              isEnabled: any, action: model.favoriteSelectedLoops)
            PanelActionButton(systemImage: "slider.horizontal.3",
                              label: "Edit practice categories for the selected loops",
                              isEnabled: any) { model.showingLoopBulkEdit = true }
        }
    }
}

/// The markers bar: delete only — a marker is a label and a time, so there is nothing
/// else to set across several at once.
struct MarkerSelectionBar: View {
    @Bindable var model: WaveformPracticeModel

    var body: some View {
        let seam = model.markerSelectionSeam
        PanelSelectionBar(title: PanelSelection.title(count: seam.selection.count,
                                                      noun: "marker", plural: "markers"),
                          allSelected: seam.selection.allSelected(of: model.markers.map(\.uid)),
                          onToggleAll: seam.toggleAll,
                          onDone: seam.end) {
            PanelActionButton(systemImage: "trash", label: "Delete selected markers",
                              isEnabled: !seam.selection.isEmpty,
                              tint: PocketColor.danger, action: seam.delete)
        }
    }
}
