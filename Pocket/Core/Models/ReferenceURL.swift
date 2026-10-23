import Foundation

/// The pure half of a reference link (ADR 0167): what counts as an acceptable URL, and what a row
/// shows underneath the title. Deliberately free of SwiftData and SwiftUI so the rules that decide
/// whether a paste is accepted can be unit-tested without a store — the project convention for
/// tempo/identity/planner logic, applied here because "is this a link?" is exactly the kind of
/// predicate that breaks silently.
///
/// **No network, ever.** Nothing in this type fetches a title, a favicon or a thumbnail. ADR 0167
/// records why: the app makes exactly one outbound request today (Formspree, ADR 0161), and
/// resolving link metadata would be a new network call made against the player's private practice
/// data — a privacy-policy change, not a nicety. The subtitle is derived from the string in hand.
enum ReferenceURL {
    /// The only two schemes a reference link may carry.
    ///
    /// This is an allowlist rather than a denylist on purpose. `openURL` will happily hand
    /// `shortcuts://`, `mailto:` or an app's own custom scheme to the system, and a practice-log
    /// field is not the place to have opinions about those. Anything that is not plain web
    /// browsing is rejected with a plain message.
    static let allowedSchemes: Set<String> = ["http", "https"]

    /// Turn what the player typed or pasted into a URL we are willing to store, or `nil`.
    ///
    /// A **scheme-less** entry is read as `https`. This is the paste case, not an edge case:
    /// copying a lesson address off a phone share sheet routinely yields `youtube.com/watch?v=…`,
    /// and rejecting that would make the feature feel broken for the input it was built for. A
    /// string that *does* carry a scheme is taken at its word and checked against
    /// `allowedSchemes`, so `javascript:` and `mailto:` are still refused rather than quietly
    /// rewritten into something they are not.
    static func normalised(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let parsed = URL(string: trimmed) else { return nil }
        if let scheme = parsed.scheme?.lowercased() {
            guard allowedSchemes.contains(scheme), parsed.host?.isEmpty == false else { return nil }
            return parsed
        }

        // No scheme: assume the player means the web. Re-parse rather than string-concatenating a
        // result, so `https://` + nonsense cannot produce a URL that only looks valid.
        guard let assumed = URL(string: "https://" + trimmed),
              assumed.host?.isEmpty == false else { return nil }
        return assumed
    }

    /// Whether `raw` would be stored. The save button reads this; the error message is the caller's.
    static func isValid(_ raw: String) -> Bool { normalised(raw) != nil }

    /// The subtitle under a reference row — the site the link points at, with case folded and the
    /// prefixes that only say which screen it was copied on dropped (`www.`, and a phone's `m.` or
    /// `mobile.`), so `WWW.YouTube.com`, `m.youtube.com` and `youtube.com` read as the same place.
    /// YouTube's short links read as `youtube.com` too: its app's share sheet hands out `youtu.be`, and
    /// the library's *Site* grouping (ADR 0275) would otherwise put one channel's lessons under two
    /// sites. Every other subdomain is kept: `tabs.ultimate-guitar.com` is a part of a site, not a copy
    /// of it. `nil` when the string is not a link we would store, which is the same condition that
    /// blocks the save.
    static func displayHost(_ raw: String) -> String? {
        guard let host = normalised(raw)?.host()?.lowercased(), !host.isEmpty else { return nil }
        let bare = withoutScreenPrefix(host)
        return siteAliases[bare] ?? bare
    }

    /// Prefixes that name a copy of a site for one kind of screen, never a part of it.
    private static let screenPrefixes = ["www.", "m.", "mobile."]

    /// Another name a site hands out for itself.
    private static let siteAliases = ["youtu.be": "youtube.com"]

    /// `host` without a screen prefix, unless dropping it leaves no domain (`m.com` stays `m.com`).
    private static func withoutScreenPrefix(_ host: String) -> String {
        guard let prefix = screenPrefixes.first(where: { host.hasPrefix($0) }) else { return host }
        let bare = String(host.dropFirst(prefix.count))
        return bare.contains(".") ? bare : host
    }
}
