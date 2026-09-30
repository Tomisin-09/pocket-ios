import Foundation

/// **Undo and redo** in Name the notes (ADR 0234 D6): every change made on this visit, one step each, so a
/// fret re-picked, a bend changed, a name given, a tap taken out or tapped in can all be put back, and put
/// back again. It replaces the single correction Undo of ADR 0231.
///
/// A step is what the sheet looked like **before** the change: the taps with their answers, the strings they
/// were placed on (a new instrument clears the frets, so undoing it has to bring the strings back with
/// them), and the note it was on. It lasts for the visit: Cancel still throws every change away, and Done
/// writes whatever the sheet holds.
///
/// Pure and SwiftUI-free (AGENTS.md), so the rules are unit-tested.
struct NamingHistory: Equatable, Sendable {

    /// What one step puts back.
    struct Step: Equatable, Sendable {
        var taps: [PieceTranscription.Tap]
        var openMidi: [Int]
        var tuningLabel: String
        /// The note the sheet was on.
        var active: Int
    }

    /// Enough for a long session of naming, and a bound, so a visit can't grow it without end.
    static let limit = 100

    private(set) var undos: [Step] = []
    private(set) var redos: [Step] = []

    var canUndo: Bool { !undos.isEmpty }
    var canRedo: Bool { !redos.isEmpty }

    /// Remember `before` as one step, when the change actually changed something the history restores. A
    /// fresh change ends the redo trail, as it does everywhere else.
    mutating func record(_ before: Step, now after: Step) {
        guard before.taps != after.taps || before.openMidi != after.openMidi else { return }
        undos.append(before)
        if undos.count > Self.limit { undos.removeFirst(undos.count - Self.limit) }
        redos.removeAll()
    }

    /// The step to go back to, with the sheet moved to the note that changed; `nil` when there's none.
    mutating func undo(from current: Step) -> Step? {
        guard var step = undos.popLast() else { return nil }
        redos.append(current)
        step.active = Self.landing(from: current.taps, to: step.taps, otherwise: step.active)
        return step
    }

    /// The step undone last, put back, with the sheet on the note it changed; `nil` when there's none.
    mutating func redo(from current: Step) -> Step? {
        guard var step = redos.popLast() else { return nil }
        undos.append(current)
        step.active = Self.landing(from: current.taps, to: step.taps, otherwise: step.active)
        return step
    }

    /// The note an undo or redo lands on: the first whose time or answer differs, so what changed is in
    /// front of the player; where the step was when nothing in the taps does (a change of strings only).
    /// A tap taken out or added lands where it was.
    static func landing(from current: [PieceTranscription.Tap], to restored: [PieceTranscription.Tap],
                        otherwise fallback: Int) -> Int {
        guard !restored.isEmpty else { return 0 }
        let shared = min(current.count, restored.count)
        let differing = (0..<shared).first { current[$0] != restored[$0] }
            ?? (current.count == restored.count ? nil : shared)
        return min(max(differing ?? fallback, 0), restored.count - 1)
    }
}
