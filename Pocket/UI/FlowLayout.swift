import SwiftUI

/// A wrapping layout — lays subviews left-to-right and wraps to the next line when the
/// current row would overflow the proposed width. Used for tag/collection chip clouds
/// where the count is small and a horizontal scroll would hide items off-screen.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, maxWidth: maxWidth)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(CGFloat.zero) { $0 + $1.height }
            + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = arrange(subviews: subviews, maxWidth: bounds.width)
        var posY = bounds.minY
        for row in rows {
            var posX = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: posX, y: posY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                posX += size.width + spacing
            }
            posY += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// Greedy line-breaking — append to the current row until the next subview would
    /// overflow, then start a fresh row. Width/height are tracked per row so both
    /// `sizeThatFits` and `placeSubviews` agree on the wrap points.
    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row(indices: [index], width: size.width, height: size.height)
            } else {
                if !current.indices.isEmpty { current.width += spacing }
                current.indices.append(index)
                current.width += size.width
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// A capsule tag chip. `selected` chips (the tags already on this loop) carry an ✕ and a
/// brighter fill so they read as "yours, tap to remove"; `suggestion` chips (tags drawn
/// from elsewhere in the library) sit quieter, "tap to add". One component, two roles —
/// keeps the loop tag editor's add/remove language symmetric (ADR 0034).
struct TagChip: View {
    enum Style { case selected, suggestion }

    let text: String
    var style: Style = .selected
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(text)
                    .font(.pocketMono(.caption))
                    .lineLimit(1)
                if style == .selected {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
            .foregroundStyle(PocketColor.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(fill))
        }
        .buttonStyle(.plain)
    }

    private var fill: Color {
        switch style {
        case .selected: Color.white.opacity(0.18)
        case .suggestion: Color.white.opacity(0.08)
        }
    }
}
