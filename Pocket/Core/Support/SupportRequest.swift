import Foundation

/// The one thing `SupportDiagnostics` needs from a `Bundle`, extracted so the version-formatting rules
/// can be tested against a dictionary instead of a bundle. `Bundle` already has this method, so the
/// conformance below is empty — subclassing `Bundle` to stub it is the alternative, and its `init()`
/// is not a seam that reliably survives.
protocol InfoDictionaryReading {
    func object(forInfoDictionaryKey key: String) -> Any?
}

extension Bundle: InfoDictionaryReading {}

/// The three facts about the installation that travel with a support message (ADR 0161).
///
/// **Deliberately Foundation-only — no UIKit.** The OS version comes from `ProcessInfo` and the model
/// identifier from `uname(3)`, both of which are plain Foundation/Darwin, so this type stays pure and
/// unit-testable and the whole support path can be exercised without a host app. That is also why
/// `current` is a factory over injected values rather than a hardcoded read: the tests build a known
/// snapshot, the app builds the live one.
///
/// **This is the whole of what is attached.** No identifier, no locale, no carrier, no storage figures,
/// nothing derived from the library. The player is shown this exact summary in the sheet before they
/// send, which is the promise `SupportRequestTests` pins — if a field is added here it appears on
/// screen too, or the disclosure has silently become a lie.
struct SupportDiagnostics: Equatable, Sendable {
    /// Marketing version and build, e.g. `1.2 (4)`.
    let appVersion: String
    /// The OS version the app is running on, e.g. `18.5`.
    let systemVersion: String
    /// The hardware identifier, e.g. `iPhone17,1`. Deliberately the raw identifier rather than a
    /// marketing name: it needs no lookup table to stay correct as new hardware ships, and it is
    /// exactly as identifying (which is to say, not).
    let deviceModel: String

    /// The one-line form shown in the sheet **and** sent in the payload. Both read this property, so
    /// the disclosure and the payload cannot drift apart.
    var summary: String {
        "Red Moon Practice \(appVersion) · iOS \(systemVersion) · \(deviceModel)"
    }

    /// The live snapshot for this installation.
    static var current: SupportDiagnostics {
        SupportDiagnostics(
            appVersion: currentAppVersion(bundle: Bundle.main),
            systemVersion: currentSystemVersion(ProcessInfo.processInfo.operatingSystemVersion),
            deviceModel: currentDeviceModel()
        )
    }

    /// `1.2 (4)`, or just `1.2` when the build number is missing. Falls back to an em dash rather than
    /// force-unwrapping — a support message that says "—" is still a support message, whereas a crash
    /// in the *contact support* screen is the worst possible place to crash.
    static func currentAppVersion(bundle: InfoDictionaryReading) -> String {
        let marketing = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (marketing, build) {
        case let (.some(marketing), .some(build)): return "\(marketing) (\(build))"
        case let (.some(marketing), .none): return marketing
        default: return "—"
        }
    }

    /// `18.5`, or `18.5.1` when there is a patch component — matching how the number is written in
    /// Settings ▸ General ▸ About, which is where a player would go to read it back to us.
    static func currentSystemVersion(_ version: OperatingSystemVersion) -> String {
        let base = "\(version.majorVersion).\(version.minorVersion)"
        return version.patchVersion == 0 ? base : base + ".\(version.patchVersion)"
    }

    /// The `hw.machine`-style identifier from `uname(3)`.
    ///
    /// On a simulator this reports the *host* architecture (`arm64`), not the simulated device — the
    /// simulator sets `SIMULATOR_MODEL_IDENTIFIER` instead. Support messages only ever come from real
    /// devices, so the simulator branch exists to keep the value honest while developing rather than
    /// because it ships.
    static func currentDeviceModel() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var info = utsname()
        guard uname(&info) == 0 else { return "—" }
        // `machine` is a fixed-size C char array surfaced to Swift as a tuple, so it is read as raw
        // bytes up to the NUL terminator rather than through a rebound pointer — the pointer form
        // needs a capacity, and the one that reads correctly is the buffer's, not the pointer's.
        let identifier = withUnsafeBytes(of: &info.machine) { buffer in
            String(bytes: buffer.prefix { $0 != 0 }, encoding: .utf8) ?? ""
        }
        return identifier.isEmpty ? "—" : identifier
    }
}

/// A message a player writes to support from inside the app (ADR 0161).
///
/// Pure value type with no SwiftUI and no `URLSession`, so validation and the payload are unit-tested
/// away from both the form and the network. `SupportSending` is what actually posts it.
///
/// **The reply address is required** (ADR 0161 D2). A support message with no return address is one we
/// can read and never answer, which is a worse outcome than the send button staying dim for a moment.
struct SupportRequest: Equatable, Sendable {
    let message: String
    let replyAddress: String
    let diagnostics: SupportDiagnostics

    /// Whether this is worth sending: a message with something in it, and an address that could
    /// plausibly receive a reply.
    var isSendable: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Self.looksLikeEmailAddress(replyAddress)
    }

    /// A deliberately loose check — one `@`, something either side of it, and a dot in the domain.
    ///
    /// **This is not validation and must not grow into it.** Formspree does the authoritative check and
    /// rejects the message if it disagrees; this exists so the common typo ("me@gmail" and a missing
    /// `@` are the two that actually happen) is caught before the round trip. Every serious attempt to
    /// match RFC 5322 with a pattern ends up rejecting addresses that genuinely work, and a player
    /// locked out of the support form by our own regex has no way left to tell us about it.
    static func looksLikeEmailAddress(_ candidate: String) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(" ") else { return false }
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        guard let dot = domain.firstIndex(of: "."), dot != domain.startIndex else { return false }
        return domain.last != "."
    }

    /// The JSON body Formspree receives.
    ///
    /// `_subject` is a Formspree special field — it sets the subject line of the email that lands in the
    /// support inbox, so the version is legible before the message is opened (the same triage signal the
    /// old `mailto:` subject carried). Every other key is an ordinary field and appears as a labelled
    /// row in that email.
    ///
    /// Values are trimmed, because a message that is mostly a trailing newline reads as an empty one.
    var formspreePayload: [String: String] {
        [
            "email": replyAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            "message": message.trimmingCharacters(in: .whitespacesAndNewlines),
            "app_version": diagnostics.appVersion,
            "ios_version": diagnostics.systemVersion,
            "device_model": diagnostics.deviceModel,
            "_subject": "Red Moon Practice \(diagnostics.appVersion) — support"
        ]
    }
}
