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

    /// A slot's glyph, with a reserved row above it for the literal `>` accent mark (opacity-toggled,
    /// not conditionally inserted, so every cell reserves the same height and the row never reflows).
    /// Weight/scale alone read as too subtle on-device to notice an accented stroke at a glance, so
    /// the mark now carries the signal explicitly; weight/scale stay as secondary reinforcement.
    @ViewBuilder
    private func slotCell(_ slot: StrumSlot, isActive: Bool) -> some View {
        VStack(spacing: 0) {
            Text(">")
                .font(.futura(.caption2, weight: .heavy))
                .opacity(slot.accented ? 1 : 0)
            if slot.isStroke {
                Image(systemName: slot.symbolName)
                    .font(.futura(.title3, weight: slot.accented ? .heavy : .semibold))
            } else {
                // A rest: a small dot the hand passes through without sounding.
                Image(systemName: slot.symbolName)
                    .font(.system(size: 6))
            }
        }
        .foregroundStyle(color(for: slot, isActive: isActive))
        .scaleEffect((isActive ? 1.35 : 1.0) * (slot.accented ? 1.15 : 1.0))
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
/// live tempo. While paused nothing lights, which is what the pure math returns.
///
/// **Shown throughout the count-in (static), with the pattern anchored to the count-in *clearing*.**
/// The engine's `currentBeat` counts *through* the count-in (it doesn't reset at the first musical
/// beat), so the lane measures from `originBeat` — pinned the instant `automatorCountdown` clears
/// (the first musical downbeat), mirroring `ChordChangeView`/`StrumChordsView` — rather than the
/// absolute beat. Before that origin is anchored the position is negative and nothing lights, so the
/// lane sits static (fully plotted) during the count instead of disappearing and popping back.
struct StrummingLaneView: View {
    let engine: StandaloneMetronomeEngine
    let pattern: StrumPattern
    var tint: Color = PocketColor.practice

    /// The engine beat the pattern measures from — the first beat after the count-in clears. `nil`
    /// until anchored, so nothing lights during the count-in.
    @State private var originBeat: Int?
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
        .onChange(of: engine.automatorCountdown) { _, countdown in
            // The count-in just cleared → this beat is the first musical downbeat; pin the pattern to it.
            if countdown == nil { anchorToDownbeat() }
        }
        .onAppear {
            // No count-in (or already cleared before this appeared) → anchor now; else wait, above.
            if engine.automatorCountdown == nil { anchorToDownbeat() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Strumming pattern: \(accessibilitySummary)")
    }

    /// Pin the pattern's origin to the current beat — called the instant the count-in clears (or on
    /// appear when there is none), so slot 0 lands on the first musical downbeat; the lane stays
    /// static until then. Idempotent (guards a second call on the same run).
    private func anchorToDownbeat() {
        guard originBeat == nil else { return }
        let beat = max(0, engine.currentBeat)   // guard the pre-first-beat -1 in the no-count-in path
        originBeat = beat
        anchoredBeat = beat
        beatOnset = .now
    }

    /// The continuous beat position at `now` relative to the anchored origin, then the pattern's
    /// active slot for it. `nil` before the origin is anchored, before beat 0, and for an empty
    /// pattern — all handled by `originBeat` / `activeSlotIndex`.
    private func activeSlot(at now: Date) -> Int? {
        guard let origin = originBeat else { return nil }
        let secondsPerBeat = 60.0 / Double(max(1, engine.bpm))
        let fraction = engine.isPlaying
            ? min(1, max(0, now.timeIntervalSince(beatOnset) / secondsPerBeat))
            : 0
        let beatPosition = Double(anchoredBeat - origin) + fraction
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
