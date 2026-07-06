import SwiftUI

/// The **presentational strum lane** (ADR 0065): a row of down/up/rest slots grouped by beat, with
/// an optional `activeIndex` lit. Holds no timing logic — the caller decides which slot is active
/// (the live `StrummingLaneView` computes it from the clock; the run-setup preview passes `nil` for
/// a static "here's the pattern" read on entry). Reused so the on-entry preview and the running
/// lane are pixel-identical.
///
/// **T10** — every colour resolves through a semantic `PocketColor` role: the active stroke in the
/// content `tint`, other strokes/rests via the ink roles, beat separators via the subtle surface
/// role — so the lane reskins under light/dark and any future theme.
struct StrumLane: View {
    let pattern: StrumPattern
    /// The slot lit now, or `nil` for a static (nothing-lit) read.
    var activeIndex: Int?
    var tint: Color = PocketColor.practice

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(pattern.slots.enumerated()), id: \.offset) { index, slot in
                if index > 0, index % pattern.slotsPerBeat == 0 { beatSeparator }
                slotCell(slot, isActive: index == activeIndex)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
    }

    @ViewBuilder
    private func slotCell(_ slot: StrumSlot, isActive: Bool) -> some View {
        Group {
            if slot.isStroke {
                Image(systemName: slot.symbolName)
                    .font(.futura(.title3, weight: .semibold))
            } else {
                // A rest: a small dot the hand passes through without sounding.
                Image(systemName: slot.symbolName)
                    .font(.system(size: 6))
            }
        }
        .foregroundStyle(color(for: slot, isActive: isActive))
        .scaleEffect(isActive ? 1.35 : 1.0)
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.07), value: isActive)
    }

    /// Slot colour by role (T10): the active stroke in the content `tint`, other strokes the
    /// primary ink dimmed, rests the secondary ink — nothing literal.
    private func color(for slot: StrumSlot, isActive: Bool) -> Color {
        if slot.isStroke {
            return isActive ? tint : PocketColor.textPrimary.opacity(0.4)
        }
        return isActive ? tint.opacity(0.7) : PocketColor.textSecondary.opacity(0.35)
    }

    /// A hairline between beats so the eye groups slots into beats — the subtle surface role.
    private var beatSeparator: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(PocketColor.surfaceBorder)
            .frame(width: 1, height: 20)
    }
}

/// The **live** strum lane over the shared metronome clock (ADR 0065 T3/T5): a thin skin over
/// `StrumLane` that reconstructs a continuous beat position from the engine's per-beat
/// `currentBeat` and asks the pure `StrumPattern` which slot is active. The engine only publishes
/// integer beats, so the lane interpolates *within* a beat — it anchors the wall-clock moment
/// `currentBeat` last advanced, then a `TimelineView(.animation)` walks the fraction elapsed at the
/// live tempo. Before beat 0 (the count-in) and while paused nothing lights, which is what the pure
/// math returns.
struct StrummingLaneView: View {
    let engine: StandaloneMetronomeEngine
    let pattern: StrumPattern
    var tint: Color = PocketColor.practice

    /// Wall-clock moment `engine.currentBeat` last advanced — the anchor the sub-beat fraction is
    /// measured from.
    @State private var beatOnset = Date.now
    /// The beat index that onset belongs to, so a re-render mid-beat keeps the same anchor.
    @State private var anchoredBeat = -1
    /// The walking-highlight preference — **off by default** as a photosensitivity precaution, and
    /// forced off under the system Reduce Motion setting. Off shows a static, fully-plotted lane.
    @AppStorage(AppSettings.Key.exerciseAnimates) private var animates = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if animates && !reduceMotion {
                TimelineView(.animation) { context in
                    StrumLane(pattern: pattern, activeIndex: activeSlot(at: context.date), tint: tint)
                }
            } else {
                StrumLane(pattern: pattern, activeIndex: nil, tint: tint)
            }
        }
        .onChange(of: engine.currentBeat) { _, newValue in
            anchoredBeat = newValue
            beatOnset = .now
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Strumming pattern: \(accessibilitySummary)")
    }

    /// The continuous beat position at `now`, then the pattern's active slot for it. Returns `nil`
    /// before beat 0 and for an empty pattern — both handled by `activeSlotIndex`.
    private func activeSlot(at now: Date) -> Int? {
        let secondsPerBeat = 60.0 / Double(max(1, engine.bpm))
        let fraction = engine.isPlaying
            ? min(1, max(0, now.timeIntervalSince(beatOnset) / secondsPerBeat))
            : 0
        let beatPosition = Double(anchoredBeat) + fraction
        return pattern.activeSlotIndex(atBeat: beatPosition)
    }

    private var accessibilitySummary: String {
        pattern.slots.map(\.label).joined(separator: ", ")
    }
}

#Preview("Strumming lane") {
    VStack(spacing: 24) {
        StrumLane(pattern: .folk, activeIndex: 2)
        StrummingLaneView(engine: StandaloneMetronomeEngine(), pattern: .folk)
    }
    .padding()
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
