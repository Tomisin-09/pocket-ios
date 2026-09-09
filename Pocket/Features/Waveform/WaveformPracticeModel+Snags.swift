import SwiftUI

// MARK: - Snags (ADR 0200)
//
// One tap on the armed transport marks the playhead as a place it went wrong. No sheet, no typing,
// no pause — the value lands at the moment of the tap, because the alternative to a tap is either
// stopping to think or carrying on and forgetting.
//
// What makes it worth marking *today*, with no Oracle anywhere near it, is `tightenToSnags`: three
// marks in the same bar are the app being told where the loop should actually be, and the answer is
// arithmetic (`SnagCluster`), not a model call.

extension WaveformPracticeModel {

    /// Mark the playhead as a snag. Deliberately the cheapest write in the app: no naming, no
    /// confirmation, no sheet — a haptic and a tick on the waveform are the whole acknowledgement.
    func dropSnag() {
        let snag = Snag(seconds: playheadFraction * duration,
                        speed: speed,
                        loopUID: activeLoop?.uid)
        context.insert(snag)
        snag.song = song           // attach → persists, and cascades with the song
        // Offer the tighter loop only when the marks actually point somewhere. Most taps will not
        // raise it, which is the intent: the offer is news, not furniture.
        if snagTightenProposal != nil { offeringSnagTighten = true }
        haptic(.medium)
    }

    /// Turn the offer down — it does not come back for these marks, only for new ones.
    func dismissSnagTighten() {
        offeringSnagTighten = false
        haptic(.light)
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
    func deleteSnag(_ snag: Snag) {
        context.delete(snag)
        // The offer was raised from marks that no longer describe the same cluster.
        if offeringSnagTighten, snagTightenProposal == nil { offeringSnagTighten = false }
        haptic(.light)
    }

    /// Snags inside the armed loop, newest first — the count the tighten offer reports.
    var snagsInActiveLoop: [Snag] {
        guard let loop = activeLoop else { return [] }
        let start = loop.startSeconds
        let end = loop.endSeconds
        return song.snags
            .filter { $0.seconds >= start && $0.seconds <= end }
            .sorted { $0.markedAt > $1.markedAt }
    }

    /// The tighter loop the marks point at, or `nil` when there is nothing worth offering.
    ///
    /// `nil` is a real answer and the common one: no marks inside the loop, or marks scattered
    /// evenly across it — which says the trouble is *not* in one place, and a suggestion that
    /// fired anyway would move a loop the player deliberately set.
    var snagTightenProposal: (start: TimeInterval, end: TimeInterval)? {
        guard let loop = activeLoop else { return nil }
        return SnagCluster.proposal(snagSeconds: song.snags.map(\.seconds),
                                    loopStart: loop.startSeconds,
                                    loopEnd: loop.endSeconds)
    }

    /// Take the proposal: lift the loop into an A/B span at the tighter bounds so the player
    /// **auditions it before it is saved**.
    ///
    /// It stops at the span rather than writing the loop, which is the point — this is a suggestion
    /// built from taps made while distracted, and it lands in the one place the app already has for
    /// "a range you are trying out" (ADR 0041). Save commits it and records the narrowing through
    /// the ordinary `saveABSpan` path (ADR 0199); ✕ discards it and the loop is untouched.
    func tightenToSnags() {
        guard let loop = activeLoop, let proposal = snagTightenProposal, duration > 0 else { return }
        offeringSnagTighten = false
        activeLoopID = loop.uid
        abEditingLoop = loop
        abSpan = .set(start: proposal.start / duration, end: proposal.end / duration)
        engine.setLoop(start: proposal.start, end: proposal.end)
        engine.seek(toSeconds: proposal.start)
        engine.play()
        haptic(.medium)
    }
}
