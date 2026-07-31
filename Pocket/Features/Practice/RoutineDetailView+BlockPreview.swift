import SwiftData
import SwiftUI

/// Block-inspection for the routine editor (ADR 0071 R4b): tapping an exercise/loop block in
/// read-only mode pushes a read-only preview. Split out of `RoutineDetailView` to keep that file
/// under the 400-line cap.
extension RoutineDetailView {
    /// One block row. In **read-only** mode an exercise or loop block is tappable — it pushes the
    /// read-only preview, signalled by a trailing chevron; rests/orphans render the plain row. In
    /// **edit** mode a unit block is instead a **button that opens its reps editor** (ADR 0076),
    /// carrying an always-visible tappable **`×N` chip** as the affordance (the chip *is* the value and
    /// the control — clearer than a bare chevron). A real Button, not a row tap gesture, so it fires
    /// reliably alongside the drag/delete affordances; a rest can't repeat, so it stays plain.
    ///
    /// In **rest-insert mode** (ADR 0127) a block row is inert in both directions: every tap on that
    /// screen belongs to a gap, so a mis-aimed one must not open a reps editor or push a preview.
    @ViewBuilder
    func blockRow(_ item: RoutineItem, number: Int) -> some View {
        if isEditing && !insertingRests && item.kind.carriesUnit && !item.isOrphaned {
            Button {
                repsEditorItem = StableRef(value: item)
                haptic(.light)
            } label: {
                HStack(spacing: 8) {
                    RoutineItemRow(item: item, number: number, showsRepsBadge: false)
                    repsChip(item)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Repeat, ×\(item.effectiveReps)")
            .accessibilityHint("Set how many times this block repeats")
        } else {
            let inspectable = !isEditing && !insertingRests && !item.isOrphaned
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
    }

    /// The always-visible tappable **`×N` chip** on an edit-mode unit block (ADR 0076) — the reps
    /// count doubling as the affordance that opens the editor. Shown even at `×1` so it's discoverable;
    /// tinted as an interactive control rather than the flatter read-only badge.
    private func repsChip(_ item: RoutineItem) -> some View {
        Text("×\(item.effectiveReps)")
            .font(.pocketMono(.subheadline))
            .foregroundStyle(PocketColor.practice)
            .padding(.horizontal, 11).padding(.vertical, 5)
            .background(Capsule().fill(PocketColor.practiceCircleWash))
            .overlay(Capsule().stroke(PocketColor.practice.opacity(0.35), lineWidth: 1))
    }

    /// The per-block **reps editor** sheet (ADR 0076), presented from an edit-mode block tap. Bound to
    /// `RoutineDetailView.repsEditorItem`; edits `item.reps` in the editing sandbox, so they're
    /// provisional until Save and re-flow the length estimate live.
    @ViewBuilder
    func repsEditorSheet(_ item: RoutineItem) -> some View {
        BlockRepsEditor(item: item)
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
    }

    /// Push a block's read-only preview, resolving the unit into the **app** context so any drill-down
    /// edits land in the real store rather than this view's editing sandbox.
    func inspect(_ item: RoutineItem) {
        if let exercise = item.exercise,
           let appExercise = appContext.model(for: exercise.persistentModelID) as? Exercise {
            // The block travels with its unit (ADR 0129/0130) — a generated block's ramp is fitted to
            // its allotted minutes, so a preview without them would draw a staircase the run won't
            // play, and the opt-out from that fit lives on the same screen.
            previewTarget = .exercise(appExercise, block: item)
        } else if let loop = item.loop,
                  let appLoop = appContext.model(for: loop.persistentModelID) as? Loop {
            // A loop block carries a mode (ADR 0104 Slice 2): ear blocks preview the ears-only surface.
            previewTarget = item.loopRunMode == .ear
                ? .earLoop(appLoop)
                : .loop(appLoop, block: item)
        } else {
            return
        }
        haptic(.light)
    }
}

extension RoutineDetailView {
    /// The pushed preview for a tapped block — the exercise or loop surface, handed the block's
    /// allotted minutes (ADR 0129) and a binding onto its opt-out from the fit (ADR 0130).
    @ViewBuilder
    func blockPreview(_ target: RoutineBlockPreviewTarget) -> some View {
        switch target {
        case .exercise(let exercise, let block):
            ExerciseBlockPreview(exercise: exercise, plannedMinutes: block.plannedMinutes,
                                 usesAuthoredLength: authoredLength(of: block))
        case .loop(let loop, let block):
            LoopBlockPreview(loop: loop, plannedMinutes: block.plannedMinutes,
                             usesAuthoredLength: authoredLength(of: block))
        case .earLoop(let loop):
            EarLoopBlockPreview(loop: loop)
        }
    }

    /// A binding onto a block's **decline the fit** flag (ADR 0130), carrying the editor's save
    /// discipline with it.
    ///
    /// The preview is only reachable in read-only mode, so a **stored** routine's sandbox holds no
    /// other in-flight edits and the toggle can commit immediately — there is no Save button on this
    /// path to commit it later. A **provisional** generated session must not save: the only thing
    /// keeping it out of the library is that nothing has written it yet, so the flag rides along with
    /// the rest of the session and lands on Save or Start. Either way the routine's estimate re-flows
    /// live, because the length section reads the same sandbox.
    private func authoredLength(of item: RoutineItem) -> Binding<Bool> {
        Binding(get: { item.usesAuthoredLength },
                set: { newValue in
                    item.usesAuthoredLength = newValue
                    if existsInStore { try? editContext.save() }
                })
    }
}

/// The per-block **Repeat** editor (ADR 0076) — a compact sheet opened by tapping a unit block in the
/// routine editor. One roomy stepper set the number of back-to-back runs, so the block list itself
/// stays a clean single line. `@Bindable` writes straight to the (sandboxed) `RoutineItem`, so the
/// change is provisional until the routine is Saved and the length estimate re-flows live.
private struct BlockRepsEditor: View {
    @Bindable var item: RoutineItem
    @Environment(\.dismiss) private var dismiss

    /// At least one run, capped so a routine can't be padded to absurdity.
    private let range = 1...9

    /// A clamped binding onto the block's repeat count (a migrated `0` reads as `1`).
    private var reps: Binding<Int> {
        Binding(get: { max(range.lowerBound, item.reps) },
                set: { item.reps = min(range.upperBound, max(range.lowerBound, $0)); haptic(.light) })
    }

    private var title: String {
        if let exercise = item.exercise { return exercise.name.isEmpty ? "Exercise" : exercise.name }
        if let loop = item.loop { return loop.name.isEmpty ? "Loop" : loop.name }
        if let song = item.song { return song.title.isEmpty ? "Song" : song.title }
        return "Block"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("×\(item.effectiveReps)")
                    .font(.pocketMono(.largeTitle))
                    .foregroundStyle(PocketColor.practice)
                    .contentTransition(.numericText())

                Stepper(value: reps, in: range) {
                    Text("Repeat this block")
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                }

                Text(item.effectiveReps == 1
                     ? "Runs once before the next block."
                     : "Runs back-to-back \(item.effectiveReps)× before the next block.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.futura(.body, weight: .bold))
                        .tint(PocketColor.practice)
                }
            }
        }
    }
}
