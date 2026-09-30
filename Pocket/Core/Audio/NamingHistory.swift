import Foundation

/// **Undo and redo** in Name the notes (ADR 0234 D6): every change made on this visit, one step each, so a
/// fret re-picked, a bend changed, a name given, a tap taken out or tapped in can all be put back, and put
/// back again. It replaces the single correction Undo of ADR 0231. The stacks are `EditHistory`'s; what a
/// step holds is `NamingStep`.
typealias NamingHistory = EditHistory<NamingStep>

/// What one step of Name the notes puts back: the taps with their answers, the strings they were placed on
/// (a new instrument clears the frets, so undoing it has to bring the strings back with them), and the note
/// it was on. Cancel still throws every change away, and Done writes whatever the sheet holds.
struct NamingStep: EditStep {
    var taps: [PieceTranscription.Tap]
    var openMidi: [Int]
    var tuningLabel: String
    /// The note the sheet was on.
    var active: Int

    func changes(_ other: NamingStep) -> Bool {
        taps != other.taps || openMidi != other.openMidi
    }

    /// The first note whose time or answer differs; where the step was when nothing in the taps does (a
    /// change of strings only).
    func landing(from current: NamingStep) -> Int {
        NamingHistory.landing(from: current.taps, to: taps, otherwise: active)
    }
}
