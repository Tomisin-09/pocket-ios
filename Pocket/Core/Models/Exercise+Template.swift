import Foundation

/// Typed access to an exercise's **content-template payload** (ADR 0065 T4/T5). The blob is
/// opaque `Data` on the model; every decode/encode of it lives here so no call site parses it
/// by hand and the forward-compatible fallback (undecodable ⇒ nil ⇒ metronome renderer) is
/// enforced in one place.
extension Exercise {

    /// The decoded **strumming** pattern, or `nil` when this isn't a strumming-template exercise
    /// (its renderer isn't `.strumming`), the payload is absent, or it can't be decoded (a newer
    /// build's blob an older build can't read). A `nil` here sends the run screen to the metronome
    /// renderer (T5).
    var strumPattern: StrumPattern? {
        guard kind == .strumming, let data = templatePayload else { return nil }
        return try? JSONDecoder().decode(StrumPattern.self, from: data)
    }

    /// Encode a strumming pattern onto the payload. **Does not touch the template** — the template
    /// is immutable and set at creation (ADR 0068, revised), so this only ever runs for an exercise
    /// that already *is* a strumming drill; it just updates the pattern the lane renders. Encode
    /// failure leaves no payload rather than a stale one (the run then falls back to the metronome
    /// underlay, the safe default, T5).
    func setStrumPattern(_ pattern: StrumPattern) {
        templatePayload = try? JSONEncoder().encode(pattern)
    }

    /// The decoded **fretboard content** — a generated run or a custom drill (ADR 0065 build 2) —
    /// or `nil` when this isn't a fretboard-template exercise, the payload is absent, or it can't be
    /// decoded. Back-compat: a pre-generative blob was written as a bare `FretboardDrill`, so a blob
    /// that isn't a `FretboardContent` is best-effort decoded as one and wrapped in `.custom`.
    var fretboardContent: FretboardContent? {
        guard kind == .fretboard, let data = templatePayload else { return nil }
        if let content = try? JSONDecoder().decode(FretboardContent.self, from: data) { return content }
        if let drill = try? JSONDecoder().decode(FretboardDrill.self, from: data) { return .custom(drill) }
        return nil
    }

    /// The rendered **fretboard drill** — the run screen's single read (T5): a generated run
    /// expanded, a custom drill as authored. `nil` sends the run to the metronome renderer, which is
    /// exactly what a fretboard-family exercise carrying no payload should do.
    var fretboardDrill: FretboardDrill? { fretboardContent?.drill(instrument: instrument) }

    /// Encode fretboard content onto the payload. Like `setStrumPattern`, it leaves the immutable
    /// template alone (ADR 0068, revised) and only updates what the board renders; an encode failure
    /// leaves no payload rather than a stale one (run falls back to the metronome underlay).
    func setFretboardContent(_ content: FretboardContent) {
        templatePayload = try? JSONEncoder().encode(content)
    }

    /// The decoded **chord progression**, or `nil` when this isn't a chords-template exercise, the
    /// payload is absent, or it can't be decoded. A `nil` sends the run to the metronome renderer (T5).
    var chordProgression: ChordProgression? {
        guard kind == .chords, let data = templatePayload else { return nil }
        return try? JSONDecoder().decode(ChordProgression.self, from: data)
    }

    /// Encode a chord progression onto the payload — leaves the immutable template alone (ADR 0068,
    /// revised); an encode failure leaves no payload rather than a stale one.
    func setChordProgression(_ progression: ChordProgression) {
        templatePayload = try? JSONEncoder().encode(progression)
    }

    /// The decoded **strum-chord sheet**, or `nil` when this isn't a strum-chords-template exercise,
    /// the payload is absent, or it can't be decoded. A `nil` sends the run to the metronome renderer
    /// (T5).
    var strumChordSheet: StrumChordSheet? {
        guard kind == .strumChords, let data = templatePayload else { return nil }
        return try? JSONDecoder().decode(StrumChordSheet.self, from: data)
    }

    /// Encode a strum-chord sheet onto the payload — leaves the immutable template alone (ADR 0068,
    /// revised); an encode failure leaves no payload rather than a stale one.
    func setStrumChordSheet(_ sheet: StrumChordSheet) {
        templatePayload = try? JSONEncoder().encode(sheet)
    }
}
