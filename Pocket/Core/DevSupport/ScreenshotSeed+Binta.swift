#if DEBUG
import Foundation

/// The shoot's **Binta**, dressed as the song player's figures show it (Tomisin, 2026-10-03).
///
/// The player figures were shot on Slow Bend (`Song.sample()`), whose waveform is generated in code: an
/// even comb of bars that looks like no song anyone has. Binta's comes from its real audio, and it's the
/// song every new player can add from Home. So the figures that draw a waveform open Binta instead.
///
/// It arrives as the starter track does — its measured tempo, downbeat, grid lines and two markers, by
/// the same `SongImporter.signpostStarterTrack` — plus what a player who has worked on it would have:
/// two loops on its bar lines and three snags. It keeps an id of its own (`importReal`), so it is never
/// mistaken for the starter track, and the walkthrough's script never runs on it.
extension ScreenshotSeed {

    /// The line under the Chords loop's first snag, for the Snags panel.
    static let bintaSnagLine = "The change into bar 11 comes in late."

    /// One of Binta's loops, from bar `from` up to bar `to`.
    private struct BarLoop {
        let name: String
        let from: Int
        let to: Int
        let speed: Double
        let repeats: Int
        let mastery: Int
    }

    /// Binta's loops, by bar: the author's own four-bar Chords loop (ADR 0220 D2) slowed to 0.75×, and
    /// the two bars the solo opens on at full speed.
    private static let bintaLoops: [BarLoop] = [
        BarLoop(name: "Chords", from: StarterTrack.chordsStart.bar, to: StarterTrack.soloStart.bar,
                speed: 0.75, repeats: 4, mastery: 4),
        BarLoop(name: "Solo opener", from: StarterTrack.soloStart.bar, to: StarterTrack.soloStart.bar + 2,
                speed: 1.0, repeats: 2, mastery: 2)
    ]

    /// Dress an imported Binta. Called by `importReal` before the song is inserted, so its markers,
    /// loops, snags and the snag's line all go in with it.
    static func dressBinta(_ song: Song) {
        guard song.duration > 0 else { return }
        SongImporter.signpostStarterTrack(song)

        let loops = bintaLoops.map { spec in
            let loop = Loop(name: spec.name,
                            start: StarterTrack.barStart(spec.from) / song.duration,
                            end: StarterTrack.barStart(spec.to) / song.duration,
                            speed: spec.speed, repeats: spec.repeats)
            loop.mastery = spec.mastery
            return loop
        }
        song.loops = loops
        for loop in loops where loop.song == nil { loop.song = song }

        // Two on Chords at its 0.75× (one with a line), one on the solo at full speed. Placed a beat or
        // more apart, so the panel's timecodes never read two as the same second.
        let beat = 60 / StarterTrack.preciseBPM
        let yesterday = Date.now.addingTimeInterval(-86_400)
        var snags: [Snag] = []
        if let chords = loops.first {
            let late = Snag(markedAt: yesterday, seconds: StarterTrack.barStart(11), speed: 0.75, loopUID: chords.uid)
            let again = Snag(markedAt: yesterday, seconds: StarterTrack.barStart(12) + 2 * beat, speed: 0.75,
                             loopUID: chords.uid)
            let line = JournalEntry.forLoop(text: bintaSnagLine, kind: .struggle, masteryAtEntry: chords.mastery,
                                            commandTempoAtEntry: nil, createdAt: yesterday)
            line.snagUID = late.uid
            chords.journal.append(line)
            snags += [late, again]
        }
        if let solo = loops.last {
            snags.append(Snag(markedAt: yesterday, seconds: StarterTrack.barStart(14) + beat, loopUID: solo.uid))
        }
        song.snags = snags
        for snag in snags { snag.song = song }
    }
}
#endif
