import SwiftUI

/// One skill in a goal editor's **Skills** list (ADR 0216 D4/D5): the keep/drop toggle, what the
/// skill actually pulls from the player's library, the ⓘ saying what it is, and — when a kept skill
/// pulls nothing — the one fix that would change that.
///
/// **Siblings, never nested.** The name area toggles and the ⓘ explains; a `Button` inside another
/// `Button`'s label fires both on one tap, so they sit side by side. The fix is a third sibling on
/// its own line. Every one of them is `.plain`, so a `List` row doesn't route a tap anywhere else.
struct GoalSkillRow: View {
    let skillID: String
    let isKept: Bool
    /// What this skill reaches, or `nil` when the editor has nothing to measure against.
    let reach: SkillReach?
    let onToggle: () -> Void
    /// Called with the fix the player tapped — only the actionable ones reach here.
    let onFix: (SkillAssociation.Fix) -> Void

    private var name: String { TechniqueTaxonomy.info(skillID)?.name ?? skillID }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Button(action: onToggle) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.futura(.body))
                                .foregroundStyle(PocketColor.textPrimary)
                            if let reach {
                                Text(GoalReach.summary(reach))
                                    .font(.futura(.caption))
                                    .foregroundStyle(PocketColor.textSecondary)
                            }
                        }
                        Spacer(minLength: 8)
                        Image(systemName: isKept ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isKept ? PocketColor.practice : PocketColor.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // The label stays the skill's name — the reach is its *value* — so a test or a
                // VoiceOver user finds the row by the same words as before the reach line existed.
                .accessibilityLabel(name)
                .accessibilityValue(reach.map(GoalReach.summary) ?? "")
                .accessibilityAddTraits(isKept ? .isSelected : [])
                InfoPopoverButton(subject: name, info: SkillExplainer.text(for: skillID))
            }
            // Only under a skill that is kept and reaches nothing: a dropped skill schedules nothing
            // by choice, and one that reaches something needs no help.
            if isKept, let reach, reach.isEmpty { fixLine }
        }
    }

    @ViewBuilder private var fixLine: some View {
        let fix = SkillAssociation.fix(for: skillID)
        switch fix {
        case .makeExercise(let template):
            Button { onFix(fix) } label: {
                Label("New \(template.displayName) exercise", systemImage: "plus.circle")
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.practice)
            }
            .buttonStyle(.plain)
        case .runLoopIn(let mode):
            hint(mode == .improvise
                 ? "Mark a loop as a backing track, then run it in Improvise."
                 : "Set a loop on one of your songs, then run it in Train your ear.")
        case .pickTargetSong:
            hint("Pick a target song below.")
        case .tagLoop(let template):
            hint("Tag a loop \u{201C}\(template.displayName)\u{201D} in its editor to bring it in.")
        case .nothing:
            hint("Nothing you can make works on this yet.")
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.futura(.caption))
            .foregroundStyle(PocketColor.textSecondary)
    }
}
