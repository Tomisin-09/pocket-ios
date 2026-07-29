import SwiftUI

/// The header a reference panel wears while multi-selecting (ADR 0125), shared by the
/// loops and markers panels so both modes read identically: a select-all circle that
/// matches the row circles, the count, the bulk actions, and Done.
///
/// The select-all control is the **same glyph the rows use**, one level up — "the circle
/// for all of them." That's why there's no separate "Select all" / "Deselect all" text
/// button: the circle's own filled/empty state already says which way a tap goes.
struct PanelSelectionHeader<Actions: View>: View {
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
    }
}

/// One bulk action in the selection header — a glyph with a real touch target, greyed
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
