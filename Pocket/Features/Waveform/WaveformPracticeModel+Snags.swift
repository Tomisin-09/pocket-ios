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

    /// Snags inside the armed loop, newest first — the count the Loops panel row shows.
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
