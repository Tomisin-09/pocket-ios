import SwiftData
import SwiftUI

/// **Rest placement** in the routine editor (ADR 0127). Split out of `RoutineDetailView` to keep
/// that file under the 400-line cap.
///
/// Two ways in, one rule. *Insert rest* tapped appends a rest at the end, as it always has; **held**,
/// it turns the block list into **rest-insert mode** — a tappable gap between every pair of blocks,
/// so a routine can be broken up in one pass instead of appending a rest and dragging it into place
/// each time. Both paths ask `RoutineBudget.allowsRest(at:in:)` the same question, and both explain a
/// refusal with the same popover, anchored where the tap happened.
extension RoutineDetailView {

    // MARK: - The two entry rows

    /// The standing *Insert rest* row (browse/edit mode). **Deliberately not a `Button`:** a SwiftUI
    /// `Button` fires its action on the *release* of a long press too, so a hold here would enter
    /// rest-insert mode **and** append a stray rest. A plain shape with separate tap/long-press
    /// gestures is the codebase's idiom for "a control that also needs a hold" (ADRs 0124/0125).
    var insertRestRow: some View {
        let slot = routine.orderedItems.count
        return HStack(spacing: 10) {
            Image(systemName: "pause.circle")
            Text("Insert rest")
            Spacer(minLength: 8)
            if !routine.items.isEmpty {
                // The hold is invisible otherwise — this is the only thing advertising the mode.
                Text("Hold to place")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary.opacity(0.7))
            }
        }
        .font(.futura(.body))
        .foregroundStyle(PocketColor.textSecondary)
        .contentShape(Rectangle())
        .onTapGesture { appendRest() }
        // 0.4 s is the house hold everywhere else (loop row, panel headers, the speed bar).
        .onLongPressGesture(minimumDuration: 0.4) { beginInsertingRests() }
        .popover(isPresented: restGuardBinding(slot)) { restGuardPopover }
        .listRowBackground(PocketColor.background)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Insert rest")
        .accessibilityHint("Adds a rest after the last block")
        .accessibilityAction(named: "Place rests between blocks") { beginInsertingRests() }
    }

    /// The way out of rest-insert mode. A plain `Button` is fine here — it takes no hold.
    var doneInsertingRestsRow: some View {
        Button {
            insertingRests = false
            restGuardSlot = nil
            haptic(.light)
        } label: {
            Label("Done placing rests", systemImage: "checkmark.circle.fill")
                .font(.futura(.body, weight: .bold))
                .foregroundStyle(PocketColor.practice)
        }
        .listRowBackground(PocketColor.background)
    }

    // MARK: - Rest-insert mode

    /// The block list with a gap row before every block and one at the end — `blocks + 1` slots,
    /// index-aligned with `RoutineBudget.restSlots`.
    @ViewBuilder var restInsertRows: some View {
        let items = routine.orderedItems
        let kinds = items.map(\.kind)
        ForEach(Array(items.enumerated()), id: \.element.uid) { pair in
            gapRow(at: pair.offset, kinds: kinds, nextBlock: pair.element)
            blockRow(pair.element, number: pair.offset + 1)
                .listRowBackground(PocketColor.background)
        }
        gapRow(at: items.count, kinds: kinds, nextBlock: nil)
    }

    /// One insertion slot. An allowed gap invites a tap; a refused one still *takes* the tap and
    /// answers it — going inert and silent would leave the user guessing why one gap did nothing.
    @ViewBuilder
    private func gapRow(at slot: Int, kinds: [RoutineItemKind], nextBlock: RoutineItem?) -> some View {
        let allowed = RoutineBudget.allowsRest(at: slot, in: kinds)
        HStack(spacing: 8) {
            Image(systemName: allowed ? "plus.circle.fill" : "pause.circle")
                .font(.futura(.footnote))
            Text(allowed ? "Rest here" : "Rest already here")
                .font(.futura(.caption))
            DashedRule()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(height: 1)
        }
        .foregroundStyle(allowed ? PocketColor.practice
                                 : PocketColor.textSecondary.opacity(0.45))
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            if allowed {
                insertRest(at: slot)
            } else {
                restGuardSlot = slot
                haptic(.light)
            }
        }
        .popover(isPresented: restGuardBinding(slot)) { restGuardPopover }
        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
        .listRowBackground(PocketColor.background)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(gapLabel(allowed: allowed, nextBlock: nextBlock))
    }

    private func gapLabel(allowed: Bool, nextBlock: RoutineItem?) -> String {
        guard allowed else { return "Rest already here" }
        guard let nextBlock else { return "Insert a rest at the end" }
        return "Insert a rest before block \(nextBlock.order + 1)"
    }

    // MARK: - Mutations

    /// Enter rest-insert mode. Needs at least one block — with an empty routine there is nothing to
    /// place a rest *between*, so the hold falls through to the plain append.
    func beginInsertingRests() {
        guard canAddBlocks else { return }
        guard !routine.items.isEmpty else { appendRest(); return }
        insertingRests = true
        restGuardSlot = nil
        haptic(.medium)
    }

    /// The tap path: a rest after the last block, refused (with an explanation) when the routine
    /// already ends on one — the same guard the gaps apply, so the two paths can't disagree.
    func appendRest() {
        let kinds = routine.orderedItems.map(\.kind)
        guard RoutineBudget.allowsRest(at: kinds.count, in: kinds) else {
            restGuardSlot = kinds.count
            haptic(.light)
            return
        }
        insertRest(at: kinds.count)
    }

    /// Put a rest in slot `slot` and re-lay every block's explicit `order` (ADR 0066 R2).
    ///
    /// The displayed order is spliced **before** the insert rather than re-read after it: a new item
    /// sharing an `order` with the block it displaces would be ordered against it by the `uid`
    /// tiebreak in `RoutineItem.ordered` — a coin flip over whether the rest lands above or below
    /// the block that was tapped.
    func insertRest(at slot: Int) {
        var ordered = routine.orderedItems
        let position = min(max(slot, 0), ordered.count)
        let rest = RoutineItem.rest(order: position)
        insert(rest)
        ordered.insert(rest, at: position)
        for (index, item) in ordered.enumerated() { item.order = index }
    }

    // MARK: - The refusal

    /// One popover, anchored to whichever slot was refused (the append row shares the trailing gap's
    /// index — they mean the same position, and only one of the two is ever on screen).
    private func restGuardBinding(_ slot: Int) -> Binding<Bool> {
        Binding(get: { restGuardSlot == slot },
                set: { showing in if !showing { restGuardSlot = nil } })
    }

    @ViewBuilder private var restGuardPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Rest already here")
                .font(.futura(.callout, weight: .bold))
                .foregroundStyle(PocketColor.textPrimary)
            Text("Two rests in a row is just one longer break. Give the rest that's already there "
                 + "more time instead.")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
        }
        // The popover sizes to its content's *ideal* width, so a long line truncates rather than
        // wraps without a fixed width plus a free height.
        .frame(width: 240, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding()
        .presentationCompactAdaptation(.popover)
    }
}

/// A horizontal hairline, stroked dashed to read as an insertion point rather than a divider.
/// A stroked `Rectangle` would draw a box; this is the single line.
private struct DashedRule: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
