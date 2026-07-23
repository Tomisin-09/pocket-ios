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
/// Slice 2's curation fields (experience / genres / dream / minutes-per-day) are additive optional
/// properties layered on later; enums land **backed by primitives**, never stored directly (the
/// enum-attribute migration rule).
@Model
final class Profile {
    /// Stable business id — mirrors the rest of the models even though there is only ever one row.
    var uid: UUID

    /// The chosen artist name, or `nil`/empty when unset. Optional and name-free-first: a `nil`
    /// name is a first-class state (the greeting falls back to its name-free copy), not a
    /// placeholder to be filled.
    var artistName: String?

    /// When the profile row was first created (the moment a name was first set).
    var createdAt: Date = Date.now

    init(uid: UUID = UUID(), artistName: String? = nil, createdAt: Date = .now) {
        self.uid = uid
        self.artistName = artistName
        self.createdAt = createdAt
    }

    /// The one profile row, if it exists yet. Returns `nil` on an untouched install (no row is
    /// inserted until a name is set) — callers treat that as the name-free state.
    static func existing(in context: ModelContext) -> Profile? {
        try? context.fetch(FetchDescriptor<Profile>()).first
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
