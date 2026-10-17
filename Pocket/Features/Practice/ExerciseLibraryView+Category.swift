import SwiftUI

/// The **category screen**'s own parts (ADR 0257 D5): the Exercises library narrowed to one template,
/// opened from a tile on the Practice hub. Split out to keep `ExerciseLibraryView` under the
/// 400-line cap.
extension ExerciseLibraryView {

    /// The card at the top of a category screen (`ExerciseCategoryHeader`).
    ///
    /// **A struct of its own, not a modifier chain built here.** Built inline, the chain sat inside
    /// `body`'s `List` builder and segfaulted the screen on open (`EXC_BAD_ACCESS` in
    /// `ViewBuilder.buildExpression`, caught by a snapshot, not by the build) — the same trap the
    /// routine editor's description field hit. A concrete view type erases the nested generic.
    func categoryHeader(_ template: ExerciseTemplate) -> ExerciseCategoryHeader {
        ExerciseCategoryHeader(template: template, countText: drillCount(presentExercises.count)) {
            creating = true
            haptic(.light)
        }
    }

    /// "1 drill" · "8 drills" — the word the hub's tile uses for the same count.
    func drillCount(_ count: Int) -> String {
        "\(count) drill\(count == 1 ? "" : "s")"
    }

    /// What an empty screen says: the whole library points at **+**, a category screen at its own
    /// **New** (or, for a retired template, says only that nothing is left).
    var emptyMessage: String {
        guard let category else {
            return "No exercises yet. Tap + to create one — a named drill you push faster over time."
        }
        return PracticeHubShelves.offersNew(category)
            ? "No \(category.displayName) drills yet. Tap New to make one."
            : "No \(category.displayName) drills left."
    }
}

/// The card at the top of a category screen: the template's glyph, its one-line description (the
/// picker's own words), how many drills it holds, and **New**, which skips the template step.
///
/// New is offered only for a template the picker still offers (`PracticeHubShelves.offersNew`): a
/// Fingerstyle screen exists for the drills made before Fingerstyle was retired, and must not make
/// more of them.
struct ExerciseCategoryHeader: View {
    let template: ExerciseTemplate
    let countText: String
    let onNew: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.iconName)
                .font(.futura(.body, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
                .frame(width: 40, height: 40)
                .background(Circle().fill(PocketColor.practiceCircleWash))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.blurb)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(countText)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Spacer(minLength: 8)
            if PracticeHubShelves.offersNew(template) { newButton }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.practiceCardWash))
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(PocketColor.background)
        .listRowSeparator(.hidden)
    }

    private var newButton: some View {
        Button(action: onNew) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                Text("New")
            }
            .font(.futura(.subheadline, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(PocketColor.practiceCTA))
            .foregroundStyle(PocketColor.background)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New \(template.displayName) exercise")
    }
}
