import SwiftUI

/// The **block-length disclosure and opt-out** (ADR 0130) — carried by the exercise and loop block
/// previews, and by nothing else.
///
/// A generated session allots each focused block a share of its minutes and fits the unit's ramp to
/// it by stretching the command dwell (ADR 0129). That fit is bounded and honest, but it was silent
/// and unconditional: a player who deliberately shaped a drill met a different one inside a session,
/// with no way to tell that had happened and no way to refuse. This states both numbers where they
/// differ, and offers the refusal.
///
/// **Deliberately not in the exercise library.** There the authored recipe *is* the truth and there is
/// nothing to disclose — and one exercise can sit in several routines fitted differently, so a library
/// note could only say something vague and permanent about a condition that is neither.
///
/// The note is omitted when the two lengths agree, which is the common case once the fit is bounded —
/// so this stays quiet rather than becoming chrome on every block.
struct BlockLengthControl: View {
    /// The block's opt-out (`RoutineItem.usesAuthoredLength`) — writes straight through to the model,
    /// as the block preview's tempo edits do (ADR 0077: a surface with no Start to defer to).
    @Binding var usesAuthoredLength: Bool
    /// Minutes this block will actually take as things stand — the fitted length, or the authored one
    /// once the fit has been declined.
    let runMinutes: Int
    /// Minutes the unit's own stored recipe takes.
    let authoredMinutes: Int
    let tint: Color

    /// Whether the session is currently changing this block's length. Drives the note, which has
    /// nothing to say when the fit lands on the authored length (or has been declined).
    private var differs: Bool { runMinutes != authoredMinutes }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { usesAuthoredLength },
                                 set: { usesAuthoredLength = $0; haptic(.light) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep my length")
                        .font(.futura(.subheadline)).foregroundStyle(PocketColor.textPrimary)
                    Text("run this block as you set it up, not as the session sized it")
                        .font(.futura(.caption2)).foregroundStyle(PocketColor.textSecondary)
                }
            }
            .tint(tint)
            .accessibilityHint("Ignore the minutes this session allotted this block")

            if differs {
                Text("Runs ~\(runMinutes) min in this session · your saved setting is ~\(authoredMinutes) min.")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.textSecondary.opacity(0.08)))
    }
}
