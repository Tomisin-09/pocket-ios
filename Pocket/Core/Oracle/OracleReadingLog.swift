import Foundation

/// When the last reading was taken (ADR 0187).
///
/// **`UserDefaults`, not a `@Model`.** The ADR's Schema line is explicit that this feature adds no
/// model, no field and no migration: the Oracle reads the store and writes back through paths that
/// already exist, and its own state — the last reading date, and later the opt-in and the quota —
/// lives here. That keeps the schema freeze's successor criteria (ADR 0189) out of it entirely.
///
/// One key, one default, one accessor. `@AppStorage` is deliberately **not** used at the call
/// sites: a literal default written beside an `@AppStorage` declaration does not mirror the
/// accessor, and every site that repeats it is a site that can drift from it. Binding the whole
/// feature to this type means the default exists once.
struct OracleReadingLog {

    /// Namespaced like the rest of the app's defaults so a stray `UserDefaults` dump is readable.
    static let lastReadingKey = "oracle.lastReadingDate"
    static let lastReadingTextKey = "oracle.lastReadingText"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// When the last reading was taken, or `nil` if none ever has been.
    ///
    /// `nil` rather than `Date.distantPast`: `OracleCadence.isAvailable` treats "never" as a
    /// distinct case — the first reading is not made to wait for a week boundary nobody mentioned
    /// at install — and a sentinel date would quietly collapse that into "a very long time ago".
    var lastReading: Date? {
        guard defaults.object(forKey: Self.lastReadingKey) != nil else { return nil }
        let seconds = defaults.double(forKey: Self.lastReadingKey)
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }

    /// The reading itself, kept so it can be **re-read all week**.
    ///
    /// Without this the gate would look like a bug: take a reading, leave the screen, come back an
    /// hour later and the week's reflection would be gone, replaced by a date. The cadence limits
    /// how often a *new* reading is drawn (D15 — it reads a period); it was never meant to limit
    /// how often you can look at the one you have.
    ///
    /// A decode failure returns `nil` and the screen offers to draw a fresh one, which is the same
    /// place a player who has never taken one lands. There is nothing here worth a migration.
    var lastReadingText: OracleReadingText? {
        guard let data = defaults.data(forKey: Self.lastReadingTextKey) else { return nil }
        return try? JSONDecoder().decode(OracleReadingText.self, from: data)
    }

    /// Record that a reading was taken, and what it said.
    ///
    /// Called when the reading is **shown**, not when it is requested. A request that failed and
    /// fell back to `LocalOracle` still produced a reading the player read, so it still spends the
    /// week — otherwise a network blip would hand out a second one.
    ///
    /// A `distress` outcome never reaches here. Nothing was drawn, nothing was spent, and the
    /// player is not put behind a week-long gate for having written what they wrote.
    func recordReading(_ reading: OracleReadingText, at date: Date) {
        defaults.set(date.timeIntervalSince1970, forKey: Self.lastReadingKey)
        if let data = try? JSONEncoder().encode(reading) {
            defaults.set(data, forKey: Self.lastReadingTextKey)
        }
    }

    /// For tests and for `Settings ▸ Your data`, where a reset must not leave this behind.
    func clear() {
        defaults.removeObject(forKey: Self.lastReadingKey)
        defaults.removeObject(forKey: Self.lastReadingTextKey)
    }
}
