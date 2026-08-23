import Foundation

/// One thing the OS told us went wrong, reduced to the handful of facts that can be shown on screen
/// in full and carried in a support message (ADR 0183).
///
/// **Deliberately not the payload.** MetricKit hands over call-stack trees, virtual-memory region
/// dumps and signpost records; none of that can be read by a player on one line, and ADR 0161 D3
/// rejected attaching anything that can't be. What survives the reduction is a kind, a date, a name
/// for what happened, and the build and OS it happened on — five short fields, no more.
///
/// `Codable` because these are persisted as a small JSON file, and `Sendable` because they cross
/// from MetricKit's delivery queue to the main actor. Neither is a `@Model`; nothing here goes near
/// SwiftData, so the enum stored below carries none of the migration risk `docs/swiftdata-gotchas.md`
/// warns about.
struct DiagnosticEvent: Codable, Equatable, Sendable, Identifiable {

    /// What the OS reported. **Only two cases, on purpose** — see `DiagnosticSummary` for why the
    /// CPU and disk-write payloads are dropped rather than mapped.
    enum Kind: String, Codable, Sendable {
        case crash
        case hang

        /// Singular and plural, in the words a player would use. A hang is a *freeze* on screen; no
        /// one outside the room the API was named in calls it a hang.
        var noun: (one: String, many: String) {
            switch self {
            case .crash: ("crash", "crashes")
            case .hang: ("freeze", "freezes")
            }
        }
    }

    /// Stable across a save/load round trip so `ForEach` keeps its rows still.
    let id: UUID
    let kind: Kind
    /// When the OS closed the window this was reported in — MetricKit dates a *payload*, not each
    /// diagnostic inside it, so several events from one delivery share a timestamp. That is the
    /// truth available, and a fabricated per-event time would be a worse one.
    let date: Date
    /// What happened, in the OS's own vocabulary — `EXC_BAD_ACCESS`, `SIGTRAP`, `froze for 8.2s`.
    /// `nil` when the payload carried nothing nameable.
    let detail: String?
    /// The app build it happened on, e.g. `1.2 (4)`. The build alone, not a marketing version: a
    /// crash report that can't be pinned to a build can't be matched to a change.
    let appBuild: String?
    /// The OS version, already shortened to `18.2`.
    let systemVersion: String?

    init(id: UUID = UUID(), kind: Kind, date: Date, detail: String? = nil,
         appBuild: String? = nil, systemVersion: String? = nil) {
        self.id = id
        self.kind = kind
        self.date = date
        self.detail = detail
        self.appBuild = appBuild
        self.systemVersion = systemVersion
    }
}

/// Every decision about diagnostics that a test can make: what is kept, for how long, how each one
/// reads as a row, and how the whole lot renders as the single line a support message can carry.
///
/// **Pure, and it imports nothing but Foundation.** `DiagnosticsRecorder` is the half that touches
/// MetricKit and it holds no judgement at all — the same split as `TrialReminderPlan` and
/// `TrialReminder` (ADR 0144 D6), and for the same reason: the OS singleton can't be driven from a
/// test, so nothing worth asserting may live behind it.
enum DiagnosticSummary {

    /// How many events are kept. Five is enough to show a pattern ("it does this every time I open a
    /// song") and few enough that the file stays a few hundred bytes and the screen stays scannable.
    static let retained = 5

    /// How far back an event stays interesting. A crash from four months and six releases ago tells
    /// support nothing about the build in front of them, and would sit at the bottom of the screen
    /// implying otherwise.
    static let maximumAge: TimeInterval = 90 * 24 * 60 * 60

    /// The events worth keeping: recent enough to matter, newest first, capped at `retained`.
    ///
    /// Applied on **write and on read**, so a file written by an older build with a longer memory
    /// still presents correctly, and so nothing has to migrate.
    static func keeping(_ events: [DiagnosticEvent], now: Date = .now) -> [DiagnosticEvent] {
        let cutoff = now.addingTimeInterval(-maximumAge)
        let recent = events.filter { $0.date >= cutoff }.sorted { $0.date > $1.date }
        return Array(recent.prefix(retained))
    }

    // MARK: - The bounded line

    /// The one line a support message may carry, or `nil` when there is nothing to say.
    ///
    /// `3 crashes since 12 Aug · EXC_BAD_ACCESS · iOS 18.2`
    ///
    /// **This is the whole of it.** ADR 0161 D3 turned down attaching logs because the moment what
    /// is attached stops being readable in full on screen, *"we send this and nothing else"* stops
    /// being a sentence we can honestly write. A bounded line passes that test where an unbounded
    /// log did not — and it is bounded here, in the pure type, rather than by whatever the OS
    /// happened to deliver.
    ///
    /// - Parameters:
    ///   - locale: pinned by the tests, so the day-and-month reads the same in every run.
    ///   - timeZone: likewise — a date near midnight formats to a different day either side of it.
    static func line(for events: [DiagnosticEvent], now: Date = .now,
                     locale: Locale = .autoupdatingCurrent,
                     timeZone: TimeZone = .autoupdatingCurrent) -> String? {
        let kept = keeping(events, now: now)
        guard let newest = kept.first, let oldest = kept.last else { return nil }
        let when = dayAndMonth(oldest.date, locale: locale, timeZone: timeZone)
        var parts = [kept.count == 1
                     ? "1 \(noun(for: kept, plural: false)) on \(when)"
                     : "\(kept.count) \(noun(for: kept, plural: true)) since \(when)"]
        if let detail = newest.detail { parts.append(detail) }
        if let systemVersion = newest.systemVersion { parts.append("iOS \(systemVersion)") }
        return parts.joined(separator: " · ")
    }

    /// `crashes` when they all are, `freezes` when they all are, `problems` when they are not both.
    /// Naming the mixture after its majority would be a small lie that reads as a fact.
    static func noun(for events: [DiagnosticEvent], plural: Bool) -> String {
        let kinds = Set(events.map(\.kind))
        guard kinds.count == 1, let only = kinds.first else { return plural ? "problems" : "problem" }
        return plural ? only.noun.many : only.noun.one
    }

    /// `12 Aug` — day and abbreviated month, no year. Everything shown is inside `maximumAge`, so a
    /// year would be noise on every line to disambiguate a case that cannot arise.
    static func dayAndMonth(_ date: Date, locale: Locale = .autoupdatingCurrent,
                            timeZone: TimeZone = .autoupdatingCurrent) -> String {
        date.formatted(Date.FormatStyle(locale: locale, timeZone: timeZone)
            .day().month(.abbreviated))
    }

    // MARK: - Rows

    /// A row's title: what happened, capitalised as a sentence — `Crash`, `Freeze`.
    static func rowTitle(for event: DiagnosticEvent) -> String {
        event.kind.noun.one.localizedCapitalized
    }

    /// A row's second line: everything else known about it, or the date alone when that is all there
    /// is. Never empty — a row with a blank subtitle looks like a rendering fault.
    static func rowDetail(for event: DiagnosticEvent, locale: Locale = .autoupdatingCurrent,
                          timeZone: TimeZone = .autoupdatingCurrent) -> String {
        var parts = [dayAndMonth(event.date, locale: locale, timeZone: timeZone)]
        if let detail = event.detail { parts.append(detail) }
        if let build = event.appBuild { parts.append("build \(build)") }
        if let systemVersion = event.systemVersion { parts.append("iOS \(systemVersion)") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Naming what the OS reported

    /// The name of a crash, from the two numbers MetricKit actually provides.
    ///
    /// `exceptionType` and `signal` arrive as bare integers, so the readable name is *our* job. The
    /// mapping is deliberately partial: these are the Mach exceptions and signals an app can
    /// plausibly hit, and an unrecognised number returns its raw form rather than a guess.
    ///
    /// **`EXC_CRASH` defers to the signal.** It is the wrapper the kernel reports for a process
    /// killed by a signal, so on its own it says only "it crashed"; the signal underneath is the
    /// half that names the fault.
    static func crashDetail(exceptionType: Int?, signal: Int?) -> String? {
        let signalName = signal.flatMap(signalNames)
        if let exceptionType, exceptionType != machExcCrash {
            return exceptionNames(exceptionType) ?? signalName ?? "exception \(exceptionType)"
        }
        return signalName ?? exceptionType.map { "exception \($0)" }
    }

    /// `froze for 8.2s`. Rounded to a tenth — MetricKit's hang durations are already a threshold
    /// crossing rather than a measurement, and three decimal places would imply otherwise.
    static func hangDetail(seconds: Double) -> String? {
        guard seconds > 0 else { return nil }
        return "froze for \(String(format: "%.1f", seconds))s"
    }

    /// `EXC_CRASH`, the wrapper case `crashDetail` looks past.
    private static let machExcCrash = 10

    private static func exceptionNames(_ code: Int) -> String? {
        switch code {
        case 1: "EXC_BAD_ACCESS"
        case 2: "EXC_BAD_INSTRUCTION"
        case 3: "EXC_ARITHMETIC"
        case 5: "EXC_SOFTWARE"
        case 6: "EXC_BREAKPOINT"
        case 9: "EXC_RPC_ALERT"
        case 11: "EXC_RESOURCE"
        case 12: "EXC_GUARD"
        default: nil
        }
    }

    private static func signalNames(_ code: Int) -> String? {
        switch code {
        case 4: "SIGILL"
        case 5: "SIGTRAP"
        case 6: "SIGABRT"
        case 8: "SIGFPE"
        case 9: "SIGKILL"
        case 10: "SIGBUS"
        case 11: "SIGSEGV"
        case 13: "SIGPIPE"
        default: nil
        }
    }

    /// `iPhone OS 18.2 (22C152)` is what MetricKit reports; `18.2` is what a player reads back off
    /// Settings ▸ General ▸ About and what `SupportDiagnostics` already writes. Same shape, so the
    /// two halves of a support message agree.
    static func shortOSVersion(_ reported: String) -> String? {
        let scanner = reported.split(whereSeparator: { $0 == " " || $0 == "(" })
        guard let version = scanner.first(where: { $0.first?.isNumber == true }) else { return nil }
        return String(version)
    }
}
