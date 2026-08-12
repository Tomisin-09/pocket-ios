import Foundation

/// Appearance override for the app's colour scheme (ADR 0062 follow-up). `.system`
/// (the default) follows the device setting, as ADR 0062 originally shipped; `.light`/
/// `.dark` pin the app regardless of the device, both to aid testing across appearances
/// on one device and as a standing user preference. `RawRepresentable` with a `String`
/// raw value so it works directly with `@AppStorage`.
enum AppearancePreference: String, CaseIterable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

/// Whether a running ramp announces its next tempo change before making it, and how insistently
/// (ADR 0131). A ramp that steps silently is found out by being wrong about it, so the default is to
/// show the change coming; `off` restores the pre-0131 behaviour for a player who wants the ramp to
/// test them.
///
/// The ADR also specifies a `sound` mode — the warning window voiced as accents on the click — which
/// is **deferred**: it needs the engine's scheduled-beat boundary (§5) and a precedence change that
/// costs a strum drill its pattern for a bar (§6), neither of which the visual carriers require. The
/// raw values here are stable, so `sound` can be added as a third case without disturbing anything
/// already stored.
enum TempoChangeWarning: String, CaseIterable, Identifiable {
    /// No warning. The ramp steps exactly as it did before ADR 0131.
    case off
    /// Show it: the run caption names the incoming tempo, the staircase pre-lights the next plateau,
    /// and the drill surface takes an edge for the duration of the window.
    case show

    static let `default` = TempoChangeWarning.show

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: return "Off"
        case .show: return "Show"
        }
    }
}

/// Persisted user preferences (Settings V1, ADR 0050). A thin `UserDefaults` wrapper so both
/// SwiftUI (`@AppStorage` on the same key) and plain engine code (the metronome, the haptic
/// helper) can read a setting without sharing an object. Keys default to **on** when never set —
/// `UserDefaults.bool` returns `false` for a missing key, so reads route through the pure
/// `resolvedBool` to honour the intended default instead of silently reading off.
///
/// UserDefaults is already declared in the privacy manifest (CA92.1), so this adds no new
/// required-reason API and needs no migration.
enum AppSettings {
    enum Key {
        static let hapticsEnabled = "hapticsEnabled"
        static let countInEnabled = "countInEnabled"
        static let countInBars = "countInBars"
        static let tempoChangeWarning = "tempoChangeWarning"
        static let clickWithdrawal = "clickWithdrawal"
        static let keepScreenAwake = "keepScreenAwake"
        static let appearance = "appearance"
        static let exerciseAnimates = "exerciseAnimates"
        static let strumClickFollowsPattern = "strumClickFollowsPattern"
        static let routineAutoStart = "routineAutoStart"
        static let routineAutoAdvance = "routineAutoAdvance"
        static let routineRestSeconds = "routineRestSeconds"
        static let routineSongLoop = "routineSongLoop"
        static let transportLoopOnLeft = "transportLoopOnLeft"
        static let transportSkipSeconds = "transportSkipSeconds"
        static let waveformMinimapVisible = "waveformMinimapVisible"
        static let waveformMarkerLabels = "waveformMarkerLabels"
        static let zoomFollowsPlayhead = "zoomFollowsPlayhead"
        static let artistNamePromptSeen = "artistNamePromptSeen"
        static let artistIntakeSeen = "artistIntakeSeen"
        static let clickTimbre = "clickTimbre"
        static let tunerInstrument = "tunerInstrument"
        static let tunerMode = "tunerMode"
        static let tunerTuning = "tunerTuning"
        static let tunerReferenceA = "tunerReferenceA"
        static let tunerChimeEnabled = "tunerChimeEnabled"
        static let accidentalPreference = "accidentalPreference"
        static let analyticsEnabled = "analyticsEnabled"
        static let analyticsPromptSeen = "analyticsPromptSeen"
        static let installDate = "installDate"
        static let hasPracticed = "hasPracticed"
        #if DEBUG
        /// DEBUG-only A/B for ADR 0140 §3. Never read in Release, which always compensates.
        static let compensateStretchLatency = "compensateStretchLatency"
        #endif
    }

    /// Count-in length is offered as whole bars in this range.
    static let countInBarsRange = 1...2

    /// Reference-pitch (concert A) calibration range offered by the tuner, in Hz (ADR 0115). A440 is
    /// the default; A432–A446 covers the ensembles a player might tune to. Free — unlike Fender, we
    /// don't gate calibration behind a paid tier (our Pro line is author-vs-run, ADR 0112).
    static let tunerReferenceRange = 432...446

    /// The tuner's default reference pitch, standard concert A.
    static let tunerReferenceDefault = 440

    /// The between-blocks rest countdown is offered in this range of seconds.
    static let routineRestSecondsRange = 5...60

    /// Whether the walking highlight animates when the player has never touched the toggle —
    /// **on** since ADR 0157.
    ///
    /// This exists as a named constant because the default lives at *seven* sites: this accessor and
    /// six `@AppStorage` declarations, whose own default values are what SwiftUI actually uses for an
    /// unset key (they do **not** consult `exerciseAnimates`). ADR 0157 §2 records that drift as the
    /// whole implementation risk of that decision; every site now reads this one value, so it can't
    /// happen. Do not inline it back to a literal.
    static let exerciseAnimatesDefault = true

    /// The song player's four display defaults (ADR 0163), named for the same reason
    /// `exerciseAnimatesDefault` is: each lives at three sites SwiftUI does **not** reconcile — the
    /// accessor below, the `@AppStorage` in `SongPlayerSettingsView`, and the `@AppStorage` in
    /// whichever waveform view reads it, that last being what SwiftUI actually uses for an unset key.
    /// Since a hold on the player opens the *same* screen the Settings hub does, a drifted literal
    /// would show two different "off"s for one key. Do not inline these back to literals.
    static let transportLoopOnLeftDefault = false
    static let waveformMinimapVisibleDefault = true
    static let waveformMarkerLabelsDefault = true
    static let zoomFollowsPlayheadDefault = false

    /// Gesture-confirmation haptics on/off. Default on.
    static var hapticsEnabled: Bool { bool(Key.hapticsEnabled) }

    /// One-bar count-in before a tempo climb / exercise run. Default on.
    static var countInEnabled: Bool { bool(Key.countInEnabled) }

    /// How many bars the count-in lasts (clamped to `countInBarsRange`). Default 1.
    static var countInBars: Int {
        let resolved = resolvedInt(storedValue: UserDefaults.standard.object(forKey: Key.countInBars),
                                   default: countInBarsRange.lowerBound)
        return min(countInBarsRange.upperBound, max(countInBarsRange.lowerBound, resolved))
    }

    /// Whether a running ramp warns before it changes tempo (ADR 0131). Default `.show`.
    static var tempoChangeWarning: TempoChangeWarning {
        resolvedTempoWarning(storedValue: UserDefaults.standard.string(forKey: Key.tempoChangeWarning))
    }

    /// Pure default-resolution: a missing or unrecognised stored value falls back to `.show` rather
    /// than crashing on a bad raw value (mirrors `resolvedAppearance`). Unrecognised covers the
    /// deferred `sound` mode, so a value written by a later build degrades to showing the warning
    /// rather than silencing it.
    static func resolvedTempoWarning(storedValue: String?) -> TempoChangeWarning {
        guard let storedValue else { return .default }
        return TempoChangeWarning(rawValue: storedValue) ?? .default
    }

    /// How far the click withdraws itself on its fixed eight-bar cycle (ADR 0132). Default `.off` —
    /// a metronome that stops clicking looks broken to anyone who hasn't opted into it (§5).
    static var clickWithdrawal: ClickWithdrawal {
        resolvedClickWithdrawal(storedValue: UserDefaults.standard.string(forKey: Key.clickWithdrawal))
    }

    /// Pure default-resolution: a missing or unrecognised stored value falls back to `.off` rather
    /// than crashing on a bad raw value (mirrors `resolvedTempoWarning`). Unrecognised degrading to
    /// `.off` is the right direction here — the failure mode of a silent click is worse than the
    /// failure mode of a click that keeps sounding.
    static func resolvedClickWithdrawal(storedValue: String?) -> ClickWithdrawal {
        guard let storedValue else { return .default }
        return ClickWithdrawal(rawValue: storedValue) ?? .default
    }

    /// Keep the screen awake on the practice/metronome surfaces. Default on — you play
    /// along hands-free, so the screen auto-locking mid-session is the wrong default.
    static var keepScreenAwake: Bool { bool(Key.keepScreenAwake) }

    /// Whether an exercise's walking highlight animates — the fretboard board and the strum lane
    /// both read this. Default **on** (ADR 0157): the walk in time is what an exercise *is* on those
    /// surfaces, and off-by-default left it undiscovered. The views still force it off under the
    /// system Reduce Motion setting, which is the real protection and the one that generalises.
    ///
    /// ⚠️ This accessor is **not** what the views read — each one owns its own `@AppStorage`
    /// declaration, so all seven share `exerciseAnimatesDefault` rather than a repeated literal
    /// (ADR 0157 §2).
    static var exerciseAnimates: Bool { bool(Key.exerciseAnimates, default: exerciseAnimatesDefault) }

    /// For a strumming / Strum & Chords drill, whether the run's metronome **follows the strum
    /// pattern** (down/up/accent/mute, rests silent — ADR 0071 R5) rather than a plain steady click.
    /// Default on; off ⇒ a standard metronome, so you produce the rhythm against a neutral pulse. The
    /// preview's "Hear the strum" button always plays the pattern regardless.
    static var strumClickFollowsPattern: Bool { bool(Key.strumClickFollowsPattern, default: true) }

    /// In a routine, auto-start each block on arrival (ADR 0071) — the **first** block always waits
    /// for a deliberate Start; this only governs the *subsequent* ones. Default on; off ⇒ every block
    /// is started by hand.
    static var routineAutoStart: Bool { bool(Key.routineAutoStart) }

    /// In a routine, whether a finished block **auto-advances** to the next one (ADR 0071 R4).
    /// Default **off** ⇒ a naturally-finished unit lands on a Done screen (optional mastery tap +
    /// inline note) that you dismiss with Continue/Finish — manual advance. On ⇒ it advances on its
    /// own, no Done gate (a deliberate Skip always bypasses the gate regardless).
    static var routineAutoAdvance: Bool { bool(Key.routineAutoAdvance, default: false) }

    /// In a routine, whether a **song block loops** and advances only when you Skip (ADR 0071) — a
    /// song is an open jam, so this is on by default. Off ⇒ a song plays through once and then
    /// auto-advances (a song carries no journal, so it never shows the Done gate).
    static var routineSongLoop: Bool { bool(Key.routineSongLoop) }

    /// How long the between-blocks rest countdown lasts, seconds (clamped to
    /// `routineRestSecondsRange`). Default 20.
    static var routineRestSeconds: Int {
        let resolved = resolvedInt(
            storedValue: UserDefaults.standard.object(forKey: Key.routineRestSeconds), default: 20)
        return min(routineRestSecondsRange.upperBound,
                   max(routineRestSecondsRange.lowerBound, resolved))
    }

    /// Which side the big idle **Loop** button sits on in the practice transport bar; the Marker
    /// takes the other side. Default **off** ⇒ Marker-left / Loop-right (the shipped arrangement);
    /// on ⇒ swapped. Applies to the idle flanking controls only.
    static var transportLoopOnLeft: Bool { bool(Key.transportLoopOnLeft, default: transportLoopOnLeftDefault) }

    /// How far the practice transport's −/+ skip buttons move, in seconds (ADR 0124). Set by holding
    /// either button; sticky across songs because how far you jump is a habit, not a per-song choice.
    /// Resolution is `TransportSkip`'s, so an unrecognised stored value falls back to its default.
    static var transportSkipSeconds: TimeInterval {
        TransportSkip.resolved(seconds: resolvedInt(
            storedValue: UserDefaults.standard.object(forKey: Key.transportSkipSeconds),
            default: Int(TransportSkip.defaultIncrement)))
    }

    /// Whether the full-song **minimap** strip shows under the detail waveform on the practice
    /// screen (P1c). Default **on** — it's the whole-song overview + scrub; off ⇒ hidden to give
    /// the waveform + loops a little more vertical room.
    static var waveformMinimapVisible: Bool {
        bool(Key.waveformMinimapVisible, default: waveformMinimapVisibleDefault)
    }

    #if DEBUG
    /// DEBUG-only: whether the playhead (and therefore the in-song click) is pulled back through the
    /// time-stretcher's latency, ADR 0140 §3. Default on — the shipping behaviour. Off reproduces the
    /// uncorrected build so the correction can be A/B'd by ear, which is the only way to settle
    /// whether `AVAudioEngine` was already compensating internally. Not a player-facing setting: the
    /// ADR closes off exposing the stretcher, and Release ignores this key entirely.
    static var compensateStretchLatency: Bool { bool(Key.compensateStretchLatency, default: true) }
    #endif

    /// Whether a marker's **label** floats over the timeline as the playhead passes near it (P2).
    /// Default **on**. Off ⇒ markers still show as triangles / count chips, but you read their
    /// labels only in the Markers panel.
    static var waveformMarkerLabels: Bool {
        bool(Key.waveformMarkerLabels, default: waveformMarkerLabelsDefault)
    }

    /// Whether pinch-to-zoom on the detail waveform re-anchors to the **playhead** as you zoom
    /// (the legacy paging), rather than to the **pinch focal point** (ADR 0098). Default **off** ⇒
    /// the spot under your fingers holds still; on ⇒ the window recenters on the playhead. Only
    /// governs the pinch gesture — page-mode during playback follows the playhead regardless.
    static var zoomFollowsPlayhead: Bool {
        bool(Key.zoomFollowsPlayhead, default: zoomFollowsPlayheadDefault)
    }

    /// Appearance override. Default `.system` — the app follows the device setting until
    /// the user opts into a pinned light/dark appearance.
    static var appearance: AppearancePreference {
        resolvedAppearance(storedValue: UserDefaults.standard.string(forKey: Key.appearance))
    }

    /// Pure default-resolution: a missing or unrecognised stored value falls back to
    /// `.system` rather than crashing on a bad raw value.
    static func resolvedAppearance(storedValue: String?) -> AppearancePreference {
        guard let storedValue else { return .system }
        return AppearancePreference(rawValue: storedValue) ?? .system
    }

    /// The metronome click timbre (ADR 0114). Read by `ClickVoice` at playback start so both the
    /// in-song click and the standalone tool voice the same choice. Default `.click` — the sound
    /// shipped before this setting existed.
    static var clickTimbre: ClickTimbre {
        resolvedClickTimbre(storedValue: UserDefaults.standard.string(forKey: Key.clickTimbre))
    }

    /// Pure default-resolution: a missing or unrecognised stored value falls back to `.click`
    /// rather than crashing on a bad raw value (mirrors `resolvedAppearance`).
    static func resolvedClickTimbre(storedValue: String?) -> ClickTimbre {
        guard let storedValue else { return .default }
        return ClickTimbre(rawValue: storedValue) ?? .default
    }

    /// The tuner's instrument axis (ADR 0115). Default `.guitar`.
    static var tunerInstrument: Instrument {
        resolvedInstrument(storedValue: UserDefaults.standard.string(forKey: Key.tunerInstrument))
    }

    /// Pure default-resolution: a missing or unrecognised value falls back to `.guitar`.
    static func resolvedInstrument(storedValue: String?) -> Instrument {
        guard let storedValue else { return .default }
        return Instrument(rawValue: storedValue) ?? .default
    }

    /// The tuner's mode — guided vs chromatic (ADR 0115). Default `.guided`.
    static var tunerMode: TunerMode {
        resolvedTunerMode(storedValue: UserDefaults.standard.string(forKey: Key.tunerMode))
    }

    /// Pure default-resolution: a missing or unrecognised value falls back to `.guided`.
    static func resolvedTunerMode(storedValue: String?) -> TunerMode {
        guard let storedValue else { return .default }
        return TunerMode(rawValue: storedValue) ?? .default
    }

    /// The tuner's reference pitch in Hz, clamped to `tunerReferenceRange` (ADR 0115). Default 440.
    static var tunerReferenceA: Int {
        let resolved = resolvedInt(storedValue: UserDefaults.standard.object(forKey: Key.tunerReferenceA),
                                   default: tunerReferenceDefault)
        return min(tunerReferenceRange.upperBound, max(tunerReferenceRange.lowerBound, resolved))
    }

    /// Whether the tuner sounds a short chime when a string settles in tune (ADR 0115). Default on.
    /// Rewarding an *objective* pitch target — not performance feedback (ADR 0070 intact).
    static var tunerChimeEnabled: Bool { bool(Key.tunerChimeEnabled, default: true) }

    /// How the player prefers to read accidentals — sharps or flats (ADR 0123). A **tiebreaker**, not a
    /// global override: anywhere a tonal centre exists the key spells the note (F major reads B♭ for
    /// everyone), and this decides only where there is nothing to spell against — the tuner, a custom
    /// chord, a rootless drill, a bare root menu. Default `.sharps`, the fretboard the app shipped with.
    static var accidentalPreference: NoteSpelling {
        resolvedSpelling(storedValue: UserDefaults.standard.string(forKey: Key.accidentalPreference))
    }

    /// Pure default-resolution: a missing or unrecognised stored value falls back to `.sharps` rather
    /// than crashing on a bad raw value (mirrors `resolvedAppearance`).
    static func resolvedSpelling(storedValue: String?) -> NoteSpelling {
        guard let storedValue else { return .default }
        return NoteSpelling(rawValue: storedValue) ?? .default
    }

    // MARK: - Analytics (ADR 0120, region-split by ADR 0147)
    //
    // `analyticsEnabled`, `analyticsDisclosureSeen` and `seedAnalyticsDefaultIfNeeded` live in
    // `AppSettings+Analytics.swift` — this file sits just under the 400-line cap.

    /// Whether a practice run has ever been *started* on this install. Purely local bookkeeping
    /// that decides when the analytics consent ask is due; written whether or not consent exists.
    ///
    /// Deliberately keyed on starting rather than finishing: a player who always stops a ramp early
    /// would otherwise never be asked at all.
    static var hasPracticed: Bool { bool(Key.hasPracticed, default: false) }

    /// Record that practice has happened. Idempotent.
    static func recordPracticed(store: UserDefaults = .standard) {
        guard !store.bool(forKey: Key.hasPracticed) else { return }
        store.set(true, forKey: Key.hasPracticed)
    }

    /// When the app was first launched, used only to bucket an install's age (`LatencyBucket`) —
    /// never sent as a date. Written on first launch regardless of consent: it is the user's own
    /// local state, exempt under Art 5(3) as strictly necessary, and only becomes an analytics input
    /// if consent later arrives. Returns `nil` before the first launch has recorded it.
    static var installDate: Date? {
        UserDefaults.standard.object(forKey: Key.installDate) as? Date
    }

    /// Record the install date once. A no-op on every launch after the first, so the value can never
    /// drift forward and quietly reset every install to "day 1".
    static func recordInstallDateIfNeeded(now: Date = .now, store: UserDefaults = .standard) {
        guard store.object(forKey: Key.installDate) == nil else { return }
        store.set(now, forKey: Key.installDate)
    }

    /// How old this install is, bucketed. Falls back to `.day1` when no install date was recorded —
    /// the honest reading for a launch that predates the key.
    static var installAgeBucket: LatencyBucket {
        guard let installDate else { return .day1 }
        return LatencyBucket(installAge: Date.now.timeIntervalSince(installDate))
    }

    private static func bool(_ key: String, default fallback: Bool = true,
                             store: UserDefaults = .standard) -> Bool {
        resolvedBool(storedValue: store.object(forKey: key), default: fallback)
    }

    /// Pure default-resolution: a missing key (`nil`) takes the default; a set key reads as its
    /// stored `Bool`. Split out so the "unset ⇒ default, not `false`" rule is unit-testable.
    static func resolvedBool(storedValue: Any?, default fallback: Bool) -> Bool {
        guard let storedValue else { return fallback }
        return (storedValue as? Bool) ?? fallback
    }

    /// Pure default-resolution for an integer setting — a missing key takes the default rather
    /// than `UserDefaults.integer`'s `0`. Caller clamps to the valid range.
    static func resolvedInt(storedValue: Any?, default fallback: Int) -> Int {
        guard let storedValue else { return fallback }
        return (storedValue as? Int) ?? fallback
    }
}
