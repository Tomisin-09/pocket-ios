import SwiftUI

/// A circular −/+ step button with **press-and-hold auto-repeat** (V1 feedback #3). A single tap
/// nudges once; holding fires repeatedly and *accelerates* — a short delay, then a cadence that
/// ramps from slow to fast the longer you hold — so a big tempo/count change no longer means
/// dozens of taps. Replaces the duplicated `stepButton` helpers across the Practice run UI
/// (EditableTempoRow, RoutineStepsControls, the loop reps row) with one styled, behaved control.
///
/// Owns its own haptics so callers pass a **pure** state mutation: one `.light` tap on press, then
/// a throttled pulse every few repeats during a hold (a per-tick haptic would buzz continuously at
/// the fast end). Because it owns the repeat, the `step` closure must clamp but must *not* haptic —
/// otherwise a hold would fire the caller's feedback dozens of times a second.
///
/// The repeat runs in a `.task(id:)` (the codebase's idiomatic cancel-on-change pattern) rather
/// than a hand-rolled `Task`, keeping it clear of Swift-6 sendable-capture pitfalls.
struct StepperButton: View {
    /// SF Symbol — "minus" / "plus".
    let symbol: String
    /// VoiceOver label, e.g. "Raise command tempo".
    let label: String
    /// Wash colour for the circular background (matches the owning control's tint).
    let tint: Color
    var diameter: CGFloat = 38
    /// One step. **Pure**: clamp + mutate state only — no haptic (this view handles feedback).
    let step: () -> Void

    /// Initial pause before a hold starts repeating (a tap must not trigger it).
    private static let holdDelay: Duration = .milliseconds(400)
    /// Repeat cadence at the start of a hold, tightened toward `minInterval` each tick.
    private static let startInterval: Duration = .milliseconds(220)
    private static let minInterval: Duration = .milliseconds(45)
    /// How much each repeat tightens the cadence (accelerating the hold).
    private static let acceleration: Duration = .milliseconds(20)

    @State private var isPressed = false
    /// Bumped on each press to (re)start the repeat `.task`; a bump cancels any prior run.
    @State private var pressToken = 0

    var body: some View {
        Image(systemName: symbol)
            .font(.futura(.body, weight: .semibold))
            .foregroundStyle(PocketColor.textPrimary)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(tint.opacity(0.18)))
            .contentShape(Circle())
            .opacity(isPressed ? 0.55 : 1)
            .scaleEffect(isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: isPressed)
            // A zero-distance drag gives press-down / lift events a Button can't: press fires one
            // step immediately; lifting before `holdDelay` leaves it a plain single tap.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        pressToken += 1
                        step()
                        haptic(.light)
                    }
                    .onEnded { _ in isPressed = false }
            )
            .task(id: pressToken) { await repeatWhileHeld() }
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            // VoiceOver can't drive the drag gesture, so give it an explicit single-step action.
            .accessibilityAction { step(); haptic(.light) }
    }

    /// After the initial hold delay, step on an accelerating cadence until the finger lifts. Checks
    /// `isPressed` right after each sleep so releasing never fires an extra step, and re-derives the
    /// interval locally so each fresh press starts slow again.
    private func repeatWhileHeld() async {
        guard isPressed else { return }   // token also bumps on release-free re-renders; guard it
        try? await Task.sleep(for: Self.holdDelay)
        var interval = Self.startInterval
        var tick = 0
        while isPressed && !Task.isCancelled {
            try? await Task.sleep(for: interval)
            guard isPressed, !Task.isCancelled else { break }
            step()
            tick += 1
            if tick.isMultiple(of: 3) { haptic(.light) }   // throttled — not every tick
            interval = max(Self.minInterval, interval - Self.acceleration)
        }
    }
}
