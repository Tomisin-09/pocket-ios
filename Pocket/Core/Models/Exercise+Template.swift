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
}
