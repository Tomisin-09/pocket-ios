import SwiftUI

/// The direction of a speed/tempo ramp — shared by the loop automator (ADR 0013, speed ×)
/// and the standalone metronome automator (ADR 0043, absolute BPM) so both draw the same
/// hero graphic and arrow.
enum RampShape: Equatable {
    case ascending, level, descending

    /// 0→1 bar-height fraction across the staircase (left→right). Level is flat.
    func fraction(at position: Double) -> Double {
        switch self {
        case .ascending: position
        case .descending: 1 - position
        case .level: 0.5
        }
    }

    var arrow: String {
        switch self {
        case .ascending: "──►"
        case .descending: "◄──"
        case .level: "───"
        }
    }

    /// The shape of a ramp from `start` to `target`. Equal values read as **level**.
    static func between(_ start: Double, _ target: Double) -> RampShape {
        if abs(target - start) < 1e-9 { return .level }
        return target > start ? .ascending : .descending
    }
}

/// The hero ramp graphic: a row of bars rising, falling, or flat left→right to show the
/// ramp's shape. `tint` lets each feature theme it (loop = green, metronome = teal) while
/// keeping the identical layout. `currentStep` (when set) lights the bar the live ramp has
/// climbed to — the metronome's in-progress staircase; left `nil` it's a static preview
/// (the loop config sheet).
struct RampStairs: View {
    let shape: RampShape
    let steps: Int
    var tint: Color = PocketColor.active
    var currentStep: Int?

    var body: some View {
        let barCount = min(max(steps, 2), 12)
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(0..<barCount, id: \.self) { index in
                let pos = Double(index) / Double(barCount - 1)   // 0→1 left→right
                let frac = shape.fraction(at: pos)               // up / down / level
                let active = isActive(bar: index, of: barCount)
                RoundedRectangle(cornerRadius: 2)
                    .fill(tint.opacity(active ? 1.0 : 0.3 + 0.4 * frac))
                    .frame(width: 13, height: 14 + 44 * frac)
                    .overlay(active ? RoundedRectangle(cornerRadius: 2)
                        .stroke(tint, lineWidth: 1.5).blur(radius: 1) : nil)
            }
        }
        .frame(height: 60, alignment: .bottom)
        .animation(.easeOut(duration: 0.2), value: shape)
        .animation(.easeOut(duration: 0.12), value: currentStep)
        .accessibilityHidden(true)
    }

    /// Map the live step onto a bar index. When one bar is drawn per step (the common case),
    /// the current step *is* the bar index — so a 5-step ramp lights bars 1…5 exactly. Only a
    /// long ramp that overflows the 12-bar cap falls back to a proportional position.
    private func isActive(bar index: Int, of barCount: Int) -> Bool {
        guard let currentStep, steps > 0 else { return false }
        if barCount == steps {
            return index == min(max(currentStep, 0), barCount - 1)
        }
        let progress = Double(min(currentStep, steps)) / Double(steps)
        return Int((progress * Double(barCount - 1)).rounded()) == index
    }
}
