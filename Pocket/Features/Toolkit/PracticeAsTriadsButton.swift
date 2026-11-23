import SwiftUI

/// **Practice as triads** (ADR 0313 D9): the button on a progression's own screen, and its context-menu
/// twin on the row in *My progressions*. Both open the New exercise form on an Arpeggios exercise playing
/// the progression as triads (`NewExerciseSeed.practiceAsTriads`), and the host's `newExerciseFlow` does
/// the rest.
///
/// It wears Practice's colour, since it leads into Practice, as *Practice now* does on a song's loop. My
/// progressions is free (0263 D1) but making an exercise isn't, so the button shows to everyone and draws
/// the lock without the plan (0256 D3); the form's own gate (`PlanDoor.newDrill`) is the wall.
struct PracticeAsTriadsButton: View {
    /// `nil` when the progression has no chord a triad plays: the button stays, disabled, and says why.
    let seed: NewExerciseSeed?
    /// Whether the progression has chords at all, so a disabled button only explains itself when there's
    /// something to explain.
    let hasChords: Bool
    let action: () -> Void

    @Environment(PlanStore.self) private var plan: PlanStore?

    var body: some View {
        Section {
            Button(action: action) {
                HStack(spacing: 8) {
                    // Practice's colour, glyph included: left alone the List draws the glyph in the Toolkit's.
                    Label(Self.title, systemImage: Self.systemImage)
                        .foregroundStyle(seed == nil ? PocketColor.textSecondary : PocketColor.practice)
                    if plan.showsPlanLocks { PlanLockBadge() }
                }
            }
            .disabled(seed == nil)
            .accessibilityLabel(Self.accessibilityLabel)
            .planLockedValue(plan.showsPlanLocks)
            .accessibilityIdentifier("progression.practiceAsTriads")
        } footer: {
            if seed != nil {
                Text("Makes an Arpeggios exercise that plays these chords as triads on three strings.")
            } else if hasChords {
                Text("Power chords have no third, so there's no triad to play.")
            }
        }
    }

    static let title = "Practice as triads"
    static let systemImage = "play.circle.fill"
    /// Spelled like the loop sheet's *Practice now*, whose label is "Practice this loop now".
    static let accessibilityLabel = "Practice this progression as triads"
}

/// The context-menu twin, for the row in *My progressions*. A menu draws one glyph, so without the plan
/// the lock stands in for the play glyph, as Home's rows swap their chevron for it.
struct PracticeAsTriadsMenuItem: View {
    let action: () -> Void

    @Environment(PlanStore.self) private var plan: PlanStore?

    var body: some View {
        Button(action: action) {
            Label(PracticeAsTriadsButton.title,
                  systemImage: plan.showsPlanLocks ? "lock.fill" : PracticeAsTriadsButton.systemImage)
        }
        .accessibilityLabel(PracticeAsTriadsButton.accessibilityLabel)
        .planLockedValue(plan.showsPlanLocks)
    }
}
