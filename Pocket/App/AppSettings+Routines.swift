import Foundation

/// The **routine player's** preferences that arrived after `AppSettings.swift` reached SwiftLint's
/// 400-line cap — split here on the `AppSettings+Home` / `+SongPlayer` precedent, by the screen the
/// setting belongs to rather than by when it was written.
extension AppSettings {

    /// Whether starting a routine **asks** whether you want to tune first (ADR 0195) — a three-button
    /// alert, one of whose answers is this setting. Bound to `routineTunerOfferDefault` at every
    /// site: an `@AppStorage` literal is what SwiftUI uses for an unset key and it does not consult
    /// this accessor, so the two are one constant or they drift apart.
    ///
    /// **Default on**, which is the opposite of where this ADR started. A default-off setting is
    /// found by nobody, and burying the tuner behind one is the exact complaint the work began from
    /// (ADR 0195 D6). A question that takes one tap to answer and one tap to silence forever can
    /// afford to be asked; a screen that takes over cannot, which is why the screen is now what
    /// *yes* leads to rather than what happens by default.
    ///
    /// The `Tune up` button between blocks is not gated by this at all — reaching a tool is not
    /// something that happens to you.
    static var routineTunerOffer: Bool {
        bool(Key.routineTunerOffer, default: routineTunerOfferDefault)
    }

    /// The one place the tune-up prompt's default is written. See `routineTunerOffer`.
    static let routineTunerOfferDefault = true
}
