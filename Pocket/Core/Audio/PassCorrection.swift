import Foundation

/// **Correcting the count while naming** (ADR 0231): a tap taken out, or a missed note added where the
/// player taps it against the recording, so finding one while naming doesn't mean counting again.
///
/// Both are the player's own acts. Nothing is detected or suggested (ADR 0225): a note is added only
/// where the player tapped it, in song seconds, the same as every other tap, never at a time worked out
/// between two others. Pure and SwiftUI-free (AGENTS.md), so it's unit-tested.
enum PassCorrection {

    /// At either end of the pass, where there's no tap on that side, how far past the end note the stretch
    /// reaches, in song seconds: about a bar's worth of room for a note missed before the first or after
    /// the last.
    static let edgeReach: TimeInterval = 1.5

    /// The stretch *Missed a note?* plays around tap `index`: from the tap before it to the tap after, so
    /// a note missed on either side is in there. At an end of the pass it reaches `edgeReach` further,
    /// never past the loop's `region`. A saved piece can outlive a change to its loop's bounds, so a
    /// region that doesn't hold every tap is ignored. `nil` for no such tap.
    static func stretch(around index: Int, in seconds: [TimeInterval],
                        region: ClosedRange<TimeInterval>?) -> (from: TimeInterval, to: TimeInterval)? {
        guard seconds.indices.contains(index) else { return nil }
        let bounds = region.flatMap { region in seconds.allSatisfy { region.contains($0) } ? region : nil }
        let note = seconds[index]
        let from = index > 0 ? seconds[index - 1]
            : min(note, max(bounds?.lowerBound ?? -.infinity, note - edgeReach))
        let to = index + 1 < seconds.count ? seconds[index + 1]
            : max(note, min(bounds?.upperBound ?? .infinity, note + edgeReach))
        return (from, to)
    }

    /// The stretch in words, as the panel says it: *Plays from note 11 to note 13.* At an end of the pass,
    /// *just before note 1* or *just after note 30*.
    static func stretchWords(around index: Int, count: Int, noun: String) -> String {
        let from = index > 0 ? "\(noun) \(index)" : "just before \(noun) 1"
        let to = index + 1 < count ? "\(noun) \(index + 2)" : "just after \(noun) \(count)"
        return "Plays from \(from) to \(to)."
    }

    /// The pass with an unnamed tap added at `second`, where the player heard the note they missed, in
    /// order among the others (after any at the same second, as a count records one); and where it went.
    static func adding(_ second: TimeInterval,
                       to taps: [PieceTranscription.Tap]) -> (taps: [PieceTranscription.Tap], index: Int) {
        var taps = taps
        let index = taps.firstIndex { $0.seconds > second } ?? taps.count
        taps.insert(PieceTranscription.Tap(seconds: second), at: index)
        return (taps, index)
    }

    /// The pass with tap `index` and its name taken out, or `nil` when there's no such tap or it's the
    /// only one: a pass keeps at least one note.
    static func removing(at index: Int, from taps: [PieceTranscription.Tap]) -> [PieceTranscription.Tap]? {
        guard taps.count > 1, taps.indices.contains(index) else { return nil }
        var taps = taps
        taps.remove(at: index)
        return taps
    }

    /// A corrected pass with any join it broke taken off. A join is from the tap before (ADR 0227 D5), and
    /// a correction can change which tap that is: an unnamed note added in between, or the one before
    /// taken out. Tidied as the correction is made, so Undo remembers the pass as it stands.
    static func tidied(_ taps: [PieceTranscription.Tap]) -> [PieceTranscription.Tap] {
        var taps = taps
        for (index, label) in NeckJoin.tidied(taps.map(\.label)).enumerated() {
            taps[index].label = label
        }
        return taps
    }

    /// Which tap is selected after tap `index` is taken out of a pass that had `count`: the one that took
    /// its place, or the new last when it was the last.
    static func selection(afterRemoving index: Int, count: Int) -> Int {
        max(0, min(index, count - 2))
    }

    /// An edit that can be undone: the pass before it and after it, and the tap that was selected. **Undo**
    /// is offered only while the pass is still exactly `after`, so any change since (a name, another edit)
    /// retires it rather than undoing more than the player sees.
    struct Undo: Equatable {
        let before: [PieceTranscription.Tap]
        let after: [PieceTranscription.Tap]
        let selected: Int
        /// What was done, as the line under the strip says it: *Took note 12 out.*
        let said: String

        func isCurrent(for taps: [PieceTranscription.Tap]) -> Bool { taps == after }
    }
}
