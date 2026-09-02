import Foundation

/// Where the Red Moon Oracle's proxy lives, per build configuration (ADR 0187 S0).
///
/// The value arrives from `Configuration/Pocket-{Debug,Release}.xcconfig` via the
/// `POCKET_API_BASE_URL` build setting, surfaced into `Info.plist`. Debug points at a proxy you
/// run yourself; **Release is deliberately empty until S4**, so a shipped build cannot make an
/// Oracle network call at all — that is the guard `docs/backlog.md` asks for, expressed as an
/// absent address rather than a hostname somebody has to remember to replace.
///
/// **No address is a supported state, not an error.** ADR 0092 §A2 requires every AI feature to
/// have a deterministic local fallback, so "the proxy is not configured" and "the proxy is
/// unreachable" land in the same place: `LocalOracle` serves the reading. Nothing about the app
/// depends on this resolving.
///
/// The decision is `resolve(_:)` — pure, `Sendable`, and unit-tested without a bundle, per
/// AGENTS.md. `current` is the thin impure wrapper that reads it.
enum OracleEndpoint {

    /// The `Info.plist` key the build setting is surfaced through.
    static let infoDictionaryKey = "POCKET_API_BASE_URL"

    /// Turn a raw build-setting value into a usable base URL, or `nil` when there isn't one.
    ///
    /// `nil` is returned for a missing key, an empty or whitespace-only value (the Release state),
    /// an unexpanded `$(…)` placeholder (which is what a mis-wired `.xcconfig` produces — it is a
    /// *string*, and without this check it would parse as a perfectly valid relative URL and fail
    /// much later, at connect time, looking like a network fault), and anything without both a
    /// scheme and a host.
    ///
    /// Requiring the scheme is what catches the `//`-is-a-comment footgun this whole file exists
    /// for: if the `$()` escape is ever dropped, the value truncates to `http:` and arrives here
    /// with no host.
    static func resolve(_ raw: String?) -> URL? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !trimmed.hasPrefix("$(") else { return nil }
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme, scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty
        else { return nil }
        return components.url
    }

    /// The base URL this build was compiled with, or `nil` when no proxy is configured.
    static func current(bundle: Bundle = .main) -> URL? {
        resolve(bundle.object(forInfoDictionaryKey: infoDictionaryKey) as? String)
    }

    /// Whether this build can reach a proxy at all. `false` in Release until S4.
    static func isConfigured(bundle: Bundle = .main) -> Bool { current(bundle: bundle) != nil }
}
