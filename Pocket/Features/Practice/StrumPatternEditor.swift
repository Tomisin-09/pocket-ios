import SwiftUI

/// The **strumming template's authoring editor** (ADR 0065 — the per-kind payload editor the ADR
/// defers and slices). A tap-to-cycle grid: each slot advances **down → up → mute → rest** on tap,
/// and a **long-press** flips the accent on whichever direction is currently showing (a no-op on a
/// rest — nothing to emphasize). A segmented control re-grids the pattern between quarters / eighths
/// / sixteenths over the bar. It is a thin skin over `StrumPattern`'s pure edit ops (`cyclingSlot`,
/// `togglingAccent`, `resized`) — the view maps gestures to those and draws the result, holding no
/// timing logic of its own (T5).
///
/// The lane **wraps by beat** (`FlowLayout`): each beat is a group of cells and the groups flow to
/// new rows, so a denser resolution grows the editor vertically instead of scrolling sideways.
///
/// **T10** — every colour is a semantic `PocketColor` role: strokes read in the content `tint`,
/// rests in the secondary ink, cell grounds in the subtle surface role, so the editor reskins
/// under light/dark and any future theme.
struct StrumPatternEditor: View {
    /// Beats per bar (the exercise's meter) — fixes how many slots each resolution produces.
    let beatsPerBar: Int
    @Binding var pattern: StrumPattern
    var tint: Color = PocketColor.practice

    /// The resolutions the segmented control offers, mapped to slots-per-beat.
    private static let resolutions: [(perBeat: Int, label: String)] =
        [(1, "Quarters"), (2, "Eighths"), (4, "Sixteenths")]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            resolutionPicker
            lane
            Text("Tap a slot to cycle it: down → up → mute → rest. Long-press to accent.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    // MARK: - Resolution

    private var resolutionPicker: some View {
        Picker("Resolution", selection: resolutionBinding) {
            ForEach(Self.resolutions, id: \.perBeat) { resolution in
                Text(resolution.label).tag(resolution.perBeat)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Strum resolution")
    }

    /// Re-grids the pattern when the resolution changes, preserving articulations by index (pure
    /// `resized`). Reads the current slots-per-beat so the right segment stays selected.
    private var resolutionBinding: Binding<Int> {
        Binding(
            get: { pattern.slotsPerBeat },
            set: { newPerBeat in
                pattern = pattern.resized(slotsPerBeat: newPerBeat, beatsPerBar: beatsPerBar)
                haptic(.light)
            })
    }

    // MARK: - Slot grid

    private var lane: some View {
        FlowLayout(spacing: 12) {
            ForEach(Array(beatGroups.enumerated()), id: \.offset) { _, group in
                HStack(spacing: 5) {
                    ForEach(group, id: \.self) { index in
                        slotButton(index: index, slot: pattern.slots[index])
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Slot indices chunked into beats — each beat lays out as one group and the groups **wrap** to
    /// new rows (via `FlowLayout`), so a denser resolution grows the lane vertically instead of
    /// scrolling off-screen. The inter-group spacing reads as the beat boundary (no separator bars).
    private var beatGroups: [[Int]] {
        let perBeat = max(1, pattern.slotsPerBeat)
        return stride(from: 0, to: pattern.slots.count, by: perBeat).map { start in
            Array(start..<min(start + perBeat, pattern.slots.count))
        }
    }

    /// A tap cycles the direction; a long-press flips the accent — composed via `exclusively(before:)`
    /// so a long-press's release doesn't *also* fire the tap action (the standard SwiftUI idiom for
    /// two gestures on one view; a plain `Button` here would double-fire since its own tap recognizer
    /// competes with a simultaneous long-press).
    private func slotButton(index: Int, slot: StrumSlot) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(PocketColor.surfaceSubtle)
                .frame(width: 34, height: 44)
            slotGlyph(slot)
        }
        .contentShape(Rectangle())
        .gesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in toggleAccent(at: index, slot: slot) }
                .exclusively(before: TapGesture().onEnded { cycleSlot(at: index) }))
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Slot \(index + 1): \(slot.label)")
        .accessibilityHint(slot.direction == .rest ? "Tap to change" : "Tap to change; long-press to accent")
    }

    private func cycleSlot(at index: Int) {
        pattern = pattern.cyclingSlot(at: index)
        haptic(.light)
    }

    private func toggleAccent(at index: Int, slot: StrumSlot) {
        guard slot.direction != .rest else { return }
        pattern = pattern.togglingAccent(at: index)
        haptic(.medium)
    }

    /// A slot's glyph, with a reserved row above it for the accent mark (`>`, opacity-toggled rather
    /// than conditionally inserted) — every slot reserves the same vertical space whether or not it's
    /// accented, so cycling/accenting never reflows the grid (only weight/scale changed before, which
    /// on-device testing showed reads as too subtle to notice a long-press actually landed).
    @ViewBuilder
    private func slotGlyph(_ slot: StrumSlot) -> some View {
        VStack(spacing: 0) {
            accentMark(slot)
            if slot.isStroke {
                Image(systemName: slot.symbolName)
                    .font(.futura(.title3, weight: slot.accented ? .heavy : .semibold))
                    .foregroundStyle(tint)
                    .scaleEffect(slot.accented ? 1.15 : 1.0)
            } else {
                Image(systemName: slot.symbolName)
                    .font(.system(size: 6))
                    .foregroundStyle(PocketColor.textSecondary.opacity(0.5))
            }
        }
    }

    /// The literal accent mark real notation uses — a small bold `>` above the stroke — rather than
    /// depending on weight/scale alone to signal it.
    private func accentMark(_ slot: StrumSlot) -> some View {
        Text(">")
            .font(.futura(.caption2, weight: .heavy))
            .foregroundStyle(tint)
            .opacity(slot.accented ? 1 : 0)
    }
}

#Preview("Strum editor") {
    struct Harness: View {
        @State private var pattern = StrumPattern.folk
        var body: some View {
            StrumPatternEditor(beatsPerBar: 4, pattern: $pattern)
                .padding()
                .background(PocketColor.background)
        }
    }
    return Harness().preferredColorScheme(.dark)
}
