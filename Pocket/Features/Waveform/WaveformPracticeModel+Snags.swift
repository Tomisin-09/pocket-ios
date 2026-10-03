import SwiftUI

// MARK: - Snags (ADR 0200)
//
// One tap on the armed transport marks the playhead as a place it went wrong. No sheet, no typing,
// no pause — the value lands at the moment of the tap, because the alternative to a tap is either
// stopping to think or carrying on and forgetting.
//
// What a mark is for is where it lands afterwards: the tick on the waveform, the Snags panel, the count
// on the loop's row, *Snags on this piece* and the export. It used to propose a tighter loop as well,
// `tightenToSnags`; ADR 0249 took that out.

extension WaveformPracticeModel {

    /// Mark the playhead as a snag. Deliberately the cheapest write in the app: no naming, no
    /// confirmation, no sheet — a haptic and a tick on the waveform are the whole acknowledgement.
    func dropSnag() {
        let snag = Snag(seconds: playheadFraction * duration,
                        speed: speed,
                        loopUID: activeLoop?.uid)
        context.insert(snag)
        snag.song = song           // attach → persists, and cascades with the song
        haptic(.medium)
    }

    /// Every snag on this song as a song fraction, for the waveform's tick band.
    var snagFractions: [Double] {
        guard duration > 0 else { return [] }
        return song.snags.map { $0.seconds / duration }
    }

    /// Every snag in playing order — the Snags panel's list (ADR 0202 D2). **By position, not by
    /// when it was tapped**: the panel is a map of where the song gives trouble, and a list sorted
    /// by recency would scatter three marks in one bar across it.
    ///
    /// **No pending-delete filter, unlike `loops` and `markers`.** Those defer a delete behind an
    /// undo window (ADR 0125) and have to hide a row that still exists; removing a snag is immediate
    /// and unconditional (ADR 0202 D3), so there is no such state to filter out.
    var snagsByTime: [Snag] {
        song.snags.sorted { $0.seconds < $1.seconds }
    }

    /// How many marks sit inside each loop's **current** span — the Loops panel's row count
    /// (ADR 0206 D1). Keyed by `uid`, and a loop with none is **absent** rather than zero: the row
    /// renders nothing for it, the same way an unrated loop shows no dots rather than five empty
    /// ones (ADR 0039).
    ///
    /// Position, not `Snag.loopUID` — the rule ADR 0203 D1 settled. A row's count and the bright
    /// ticks on the canvas are then the same set, which is the only way the two can be read together.
    var snagCountsByLoop: [UUID: Int] {
        let marks = song.snags.map(\.seconds)
        guard !marks.isEmpty else { return [:] }
        var counts: [UUID: Int] = [:]
        for loop in loops {
            let start = loop.startSeconds
            let end = loop.endSeconds
            let count = marks.filter { $0 >= start && $0 <= end }.count
            if count > 0 { counts[loop.uid] = count }
        }
        return counts
    }

    /// Loop names by `uid`, for the Snags panel's row captions (ADR 0203 D2). Built once per render
    /// rather than searched per row, and it resolves **only what still exists** — a snag whose loop
    /// was deleted simply has no caption, which is the honest rendering: the mark outlives the loop
    /// by design (ADR 0200), so its caption has to be allowed to not.
    var loopNamesByUID: [UUID: String] {
        Dictionary(loops.map { ($0.uid, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    /// Each snag's line by the snag's `uid` (ADR 0238), for the panel's rows: one pass over the Journals
    /// per render rather than a search per row. Every loop on the song, the same set *Name the notes*
    /// reads (`Loop.line(forSnag:)`), so the two can't disagree about a snag's line.
    var snagLinesByUID: [UUID: String] {
        SnagLine.lines(in: song.loops.flatMap(\.journal)).mapValues(\.text)
    }

    /// `snag`'s line, from any of the song's loops.
    func snagLine(for snag: Snag) -> JournalEntry? {
        SnagLine.lines(in: song.loops.flatMap(\.journal))[snag.uid]
    }

    /// The loop a new line on `snag` goes to (`SnagLine.home`), or `nil` when no loop has it. Reads
    /// `loops`, so a loop waiting out its undo window is never given a line it's about to lose.
    func snagLineHome(for snag: Snag) -> Loop? {
        let spans = loops.map { SnagLine.Span(uid: $0.uid, start: $0.startSeconds, end: $0.endSeconds) }
        let home = SnagLine.home(madeUnder: snag.loopUID, at: snag.seconds, among: spans)
        return loops.first { $0.uid == home }
    }

    /// Hold a snag row — write or change its line.
    func editSnagLine(_ snag: Snag) {
        editingSnag = StableRef(value: snag)
    }

    /// Save `draft` as `snag`'s line, straight to the Journal like *Name the notes* does (ADR 0234 D7):
    /// change the line it has, take it out when emptied, or write a new one, of `SnagLine.kind`, to
    /// `snagLineHome`.
    func saveSnagLine(_ draft: String, for snag: Snag) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if let line = snagLine(for: snag) {
            guard text != line.text else { return }
            if text.isEmpty {
                JournalWriter.delete(line, from: context)
            } else {
                JournalWriter.update(line, text: text, kind: line.kind)
            }
        } else if let home = snagLineHome(for: snag) {
            guard JournalWriter.add(to: .loop(home), text: text,
                                    kind: SnagLine.kind(markedWhileNaming: snag.markedWhileNaming),
                                    snagUID: snag.uid, into: context) else { return }
        } else {
            return
        }
        try? context.save()
        haptic(.light)
    }

    /// Tap a snag row — go there and play, like a marker row.
    func seekToSnag(_ snag: Snag) {
        engine.seek(toSeconds: snag.seconds)
        engine.play()
        haptic(.light)
    }

    /// Remove one snag. **No undo toast**, unlike a loop or a marker (ADR 0202 D3): those carry
    /// authored content — a name, a colour, a mastery — and losing one by a mis-tap costs work. A
    /// snag is an anonymous timestamp, so the toast would guard nothing and would cost the panel a
    /// row of chrome per tap. Deleting the last one also folds the panel away, which is the only
    /// state it has to say something about.
    ///
    /// A snag with a line (ADR 0238) still has no toast: the line is a Journal note that only points at
    /// the snag, so it stays, an ordinary note on its loop. The words are the authored part, and they
    /// aren't lost.
    func deleteSnag(_ snag: Snag) {
        context.delete(snag)
        haptic(.light)
    }
}
