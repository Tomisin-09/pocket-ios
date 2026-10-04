import Foundation

/// **How fast you can play a song**, read off its loops (ADR 0250 D8): the slowest measured loop's
/// command tempo, because the whole song only goes as fast as its slowest part. Shown beside the
/// song's mastery dots, never folded into them — the two axes stay two (ADR 0036).
///
/// A fact read off the loops, not a formula: no weighting, no average, no score. Pure and
/// **SwiftData-/SwiftUI-free** so the edges (nothing measured, a tie, exactly 100%) stay unit-tested
/// per AGENTS.md; the caller hands it plain values.
struct SongSpeed: Equatable {

    /// One loop, as this reading needs it.
    struct Part: Equatable {
        var name: String
        /// The **measured** command (`Loop.commandTempo`), `×` of original — `nil` when never set.
        var command: Double?
        /// A backing track is played along to, not practised (ADR 0135), so its speed says nothing
        /// about how fast you can play the song.
        var isBackingTrack = false
    }

    /// The slowest measured loop's command, in the whole percent its row badge shows.
    let percent: Int
    /// That loop's name, for the song details sheet.
    let loopName: String

    /// The percent at and above which a loop is at the record's own speed.
    static let fullSpeedPercent = 100

    /// Whether `command` (`×` of original) is at full speed — judged on the **rounded percent** the
    /// loop badge shows, so the app never calls a loop full speed while its badge reads 99%, or the
    /// reverse. The one rule the title strip and the *Mastered* tile share (ADR 0250 D8, D10).
    static func isFullSpeed(_ command: Double) -> Bool {
        isFullSpeed(percent: LoopProgressFormat.percent(command) ?? 0)
    }

    /// The comparison itself, once — `isFullSpeed(_:)` and the strip's `isFullSpeed` both read it.
    private static func isFullSpeed(percent: Int) -> Bool { percent >= fullSpeedPercent }

    /// The reading for these loops, or `nil` when none is measured. Unmeasured loops are skipped,
    /// as the mastery rollup skips unrated ones; backing tracks are left out. A tie goes to the first
    /// in the order given — the caller passes the song's loops in song order.
    static func reading(_ parts: [Part]) -> SongSpeed? {
        let measured = parts.compactMap { part -> (name: String, command: Double)? in
            guard !part.isBackingTrack, let command = part.command else { return nil }
            return (part.name, command)
        }
        guard let slowest = measured.min(by: { $0.command < $1.command }) else { return nil }
        return SongSpeed(percent: LoopProgressFormat.percent(slowest.command) ?? 0,
                         loopName: slowest.name)
    }

    /// Whether every measured loop is at full speed.
    var isFullSpeed: Bool { Self.isFullSpeed(percent: percent) }

    /// The line under the dots on the player's title strip — "slowest 60%", or "full speed".
    var stripLabel: String { isFullSpeed ? "full speed" : "slowest \(percent)%" }

    /// What VoiceOver reads for that line.
    var accessibilityLabel: String {
        isFullSpeed ? "All loops at full speed" : "Slowest loop at \(percent) percent"
    }
}
