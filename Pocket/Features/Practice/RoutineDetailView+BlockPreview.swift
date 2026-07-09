import SwiftData
import SwiftUI

/// Block-inspection for the routine editor (ADR 0071 R4b): tapping an exercise/loop block in
/// read-only mode pushes a read-only preview. Split out of `RoutineDetailView` to keep that file
/// under the 400-line cap.
extension RoutineDetailView {
    /// One block row. In read-only mode an **exercise or loop** block is tappable — it pushes the
    /// read-only preview, signalled by a trailing chevron; rests/orphans and edit mode (which owns
    /// drag/delete) render the plain row.
    @ViewBuilder
    func blockRow(_ item: RoutineItem, number: Int) -> some View {
        let inspectable = !isEditing && !item.isOrphaned
            && (item.exercise != nil || item.loop != nil)
        HStack(spacing: 8) {
            RoutineItemRow(item: item, number: number)
            if inspectable {
                Image(systemName: "chevron.right")
                    .font(.futura(.caption, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if inspectable { inspect(item) } }
    }

    /// Push a block's read-only preview, resolving the unit into the **app** context so any drill-down
    /// edits land in the real store rather than this view's editing sandbox.
    func inspect(_ item: RoutineItem) {
        if let exercise = item.exercise,
           let appExercise = appContext.model(for: exercise.persistentModelID) as? Exercise {
            previewTarget = .exercise(appExercise)
        } else if let loop = item.loop,
                  let appLoop = appContext.model(for: loop.persistentModelID) as? Loop {
            previewTarget = .loop(appLoop)
        } else {
            return
        }
        haptic(.light)
    }
}
