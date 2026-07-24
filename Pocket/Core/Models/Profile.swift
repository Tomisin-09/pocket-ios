import Foundation
import SwiftData

/// The player's **local, account-free profile** (ADR 0113). Slice 1 carries a single job: the
/// **artist name** that personalises the home-screen greeting ("Evening, Vega"). Deliberately not
/// PII — a chosen stage name, offered *after* a first session, never demanded at the door. Nothing
/// leaves the device; there is no account and no sync.
///
/// **Singleton.** The app keeps at most one `Profile` row. It is created lazily — a row is only
/// inserted once a name is actually set (`setArtistName`), so an untouched install carries no
/// profile at all and the greeting simply reads name-free (`artistName == nil`). Read the current
/// name in views with `@Query` and take `.first`; mutate through `setArtistName` so the
/// fetch-or-create + empty-name cleanup stays in one place.
///
/// Follows the model discipline (ADR 0011/0012/0036): a `uid: UUID` business id and **declaration
/// defaults** on every non-optional attribute so SwiftData lightweight migration stays additive.
/// Slice 2's curation fields (experience / genres / dream / minutes-per-day) are the additive
/// optional properties below; each enum is **backed by a primitive** (raw `String`/`[String]`) with a
/// computed case accessor, never stored directly — the enum-attribute migration rule
/// (`docs/swiftdata-gotchas.md`). The intake writes them once and Settings edits them any time;
/// nothing here is PII.
@Model
final class Profile {
    /// Stable business id — mirrors the rest of the models even though there is only ever one row.
    var uid: UUID

    /// The chosen artist name, or `nil`/empty when unset. Optional and name-free-first: a `nil`
    /// name is a first-class state (the greeting falls back to its name-free copy), not a
    /// placeholder to be filled.
    var artistName: String?

    /// When the profile row was first created (the moment a name was first set, or the intake was
    /// completed — whichever comes first).
    var createdAt: Date = Date.now

    // MARK: Curation fields (ADR 0113 Slice 2) — declared intent the intake collects, primitive-backed.

    /// Self-rated experience (`ArtistExperience.rawValue`), or `nil` if skipped. → fresh-exercise
    /// tempo default + planner difficulty.
    var experienceRaw: String?
    /// Chosen genres (`MusicGenre.rawValue`s), empty if skipped. → preset ordering + planner emphasis.
    var genresRaw: [String] = []
    /// The dream (`MusicalDream.rawValue`), or `nil` if skipped. → planner emphasis (Slice 3).
    var dreamRaw: String?
    /// Typical daily minutes (`PracticeMinutes.rawValue`), or `nil` if skipped. → planner session
    /// length + tempo defaults.
    var minutesPerDayRaw: String?

    /// The player's **preferred instrument** (`Instrument.rawValue`, ADR 0116) — the default a freshly
    /// created exercise picks up for its instrument axis. `nil`/unrecognised reads as `.guitar`, so an
    /// untouched install and every pre-0116 profile default to guitar (additive migration).
    var preferredInstrumentRaw: String?

    init(uid: UUID = UUID(), artistName: String? = nil, createdAt: Date = .now) {
        self.uid = uid
        self.artistName = artistName
        self.createdAt = createdAt
    }

    // MARK: Computed enum accessors — the typed view of the primitive-backed curation fields.

    /// Experience as its enum case (or `nil` when unset / unrecognised on decode).
    var experience: ArtistExperience? {
        get { experienceRaw.flatMap(ArtistExperience.init(rawValue:)) }
        set { experienceRaw = newValue?.rawValue }
    }

    /// Genres as enum cases (unrecognised raw values are dropped, so a future rename decodes cleanly).
    var genres: [MusicGenre] {
        get { genresRaw.compactMap(MusicGenre.init(rawValue:)) }
        set { genresRaw = newValue.map(\.rawValue) }
    }

    /// The dream as its enum case (or `nil` when unset / unrecognised).
    var dream: MusicalDream? {
        get { dreamRaw.flatMap(MusicalDream.init(rawValue:)) }
        set { dreamRaw = newValue?.rawValue }
    }

    /// Typical daily minutes as its enum case (or `nil` when unset / unrecognised).
    var minutesPerDay: PracticeMinutes? {
        get { minutesPerDayRaw.flatMap(PracticeMinutes.init(rawValue:)) }
        set { minutesPerDayRaw = newValue?.rawValue }
    }

    /// The preferred instrument as its enum case — **always resolves**, falling back to `.guitar` when
    /// unset or unrecognised (unlike the optional curation fields, an exercise always needs an
    /// instrument default, and guitar is it). The create flow reads this for a fresh drill's axis.
    var preferredInstrument: Instrument {
        get { preferredInstrumentRaw.flatMap(Instrument.init(rawValue:)) ?? .guitar }
        set { preferredInstrumentRaw = newValue.rawValue }
    }

    /// The one profile row, if it exists yet. Returns `nil` on an untouched install (no row is
    /// inserted until a name is set *or* the intake writes curation) — callers treat that as the
    /// name-free / no-preferences state.
    static func existing(in context: ModelContext) -> Profile? {
        try? context.fetch(FetchDescriptor<Profile>()).first
    }

    /// The singleton row, inserting it if none exists yet. Used by the curation writers, which — unlike
    /// the name — legitimately create a row for a still-nameless player (the first-launch intake runs
    /// before a name is earned). The greeting stays name-free while `artistName` is `nil`.
    static func fetchOrCreate(in context: ModelContext) -> Profile {
        if let existing = existing(in: context) { return existing }
        let profile = Profile()
        context.insert(profile)
        return profile
    }

    /// Write the four curation fields from the intake (or Settings) in one place. Each argument is
    /// optional/absent-friendly: a skipped question passes `nil` (or `[]` for genres) and clears that
    /// field, so re-running the intake or editing in Settings is a plain overwrite. Creates the
    /// singleton row on first use — a player can decline the artist name yet still declare intent.
    static func setCuration(experience: ArtistExperience?, genres: [MusicGenre],
                            dream: MusicalDream?, minutesPerDay: PracticeMinutes?,
                            in context: ModelContext) {
        let profile = fetchOrCreate(in: context)
        profile.experience = experience
        profile.genres = genres
        profile.dream = dream
        profile.minutesPerDay = minutesPerDay
        try? context.save()
    }

    /// Set the preferred instrument, creating the singleton row on first use — a player can declare
    /// what they play without ever setting an artist name (mirrors `setCuration`). Feeds fresh
    /// exercises' instrument default (ADR 0116).
    static func setPreferredInstrument(_ instrument: Instrument, in context: ModelContext) {
        let profile = fetchOrCreate(in: context)
        profile.preferredInstrument = instrument
        try? context.save()
    }

    /// Set (or clear) the artist name, creating the singleton row on first use. Trims whitespace;
    /// an empty/blank name clears `artistName` back to `nil` rather than storing an empty string,
    /// so the greeting reverts to name-free. Inserts a fresh row only when there is a non-empty
    /// name to store and none exists yet — an empty set on an untouched install is a no-op, which
    /// keeps the "don't insert until named" invariant.
    static func setArtistName(_ name: String?, in context: ModelContext) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (trimmed?.isEmpty ?? true) ? nil : trimmed

        if let profile = existing(in: context) {
            profile.artistName = value
        } else if let value {
            context.insert(Profile(artistName: value))
        }
        try? context.save()
    }
}
