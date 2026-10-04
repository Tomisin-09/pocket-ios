#if DEBUG
import Foundation

/// The shoot's Slow Bend, laid out for the song map (ADR 0232), under `-seedSongMap`.
///
/// `SongMapPreview.song()` is already the state the map's figures ask for (sections, a pin, chords and
/// notes pieces, a named riff, a repeat and a "same as" section) and it is Slow Bend by Jack Trader, so the
/// figures name the song every other page names. It is not the demo song's *shape*, though: different
/// loops, a different length, sections. That is why it has a pass of its own (`map` in
/// `shoot-manual.sh`) rather than replacing `Song.sample()` everywhere, where every player figure would move.
///
/// On top of the preview, three snags, for the saved piece's `Snags on this piece` and Name the notes: two
/// on the riff at 75% (one with a line), one on the chorus bend at full speed. (The Snags panel's own
/// figure is shot on Binta, in the player pass — `ScreenshotSeed+Binta`.)
/// The preview itself is left alone; its snapshot test reads it.
extension ScreenshotSeed {

    /// The line under the riff's first snag. In the panel, in Name the notes and under the saved piece.
    static let snagLine = "The jump to the top string lands late."

    /// Slow Bend for this launch: the mapped one under `-seedSongMap`, the demo song otherwise.
    static func heroSong(arguments: [String] = CommandLine.arguments) -> Song {
        arguments.contains(UITestHooks.songMapArgument) ? mappedSlowBend() : Song.sample()
    }

    static func mappedSlowBend() -> Song {
        let song = SongMapPreview.song()
        let yesterday = Date.now.addingTimeInterval(-86_400)
        var snags: [Snag] = []

        if let riff = song.loops.first(where: { $0.name == "Verse riff" }),
           let taps = riff.transcription?.taps, taps.count >= 8 {
            // On the riff's 5th and last notes, so each snag sits on a note of the saved piece. Not the
            // 7th: it is 0.66 s from the 5th, and the panel's timecodes showed both as 0:23.
            let late = Snag(markedAt: yesterday, seconds: taps[4].seconds, speed: 0.75, loopUID: riff.uid)
            let again = Snag(markedAt: yesterday, seconds: taps[7].seconds, speed: 0.75, loopUID: riff.uid)
            let line = JournalEntry.forLoop(text: snagLine, kind: .struggle, masteryAtEntry: riff.mastery,
                                            commandTempoAtEntry: nil, createdAt: yesterday)
            line.snagUID = late.uid
            riff.journal.append(line)
            snags += [late, again]
        }
        if let bend = song.loops.first(where: { $0.name == "Chorus bend" }) {
            let middle = (bend.start + bend.end) / 2 * song.duration
            snags.append(Snag(markedAt: yesterday, seconds: middle, loopUID: bend.uid))
        }

        song.snags = snags
        for snag in snags { snag.song = song }
        // The preview's pieces carry no date, and the Journal leaves an undated piece out until the next
        // launch's `PieceDateBackfill` stamps it. Dated here by that same rule, so Pieces holds them on
        // the launch that seeds them rather than on whichever launch comes second.
        for loop in song.loops { PieceDateBackfill.apply(to: loop, now: yesterday) }
        return song
    }
}
#endif
