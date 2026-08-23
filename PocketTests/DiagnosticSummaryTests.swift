import XCTest
@testable import Pocket

/// The whole of the diagnostics judgement (ADR 0183): what is kept, how it reads, and what a support
/// message may carry. `DiagnosticsRecorder` holds none of it — it talks to MetricKit and nothing else
/// — so everything worth pinning is pinned here.
///
/// The locale and time zone are **pinned on every call that formats a date**. `12 Aug` is `Aug 12` in
/// `en_US` and a different day either side of midnight in another zone, so an unpinned assertion is a
/// test that passes on the machine it was written on.
final class DiagnosticSummaryTests: XCTestCase {

    private let locale = Locale(identifier: "en_GB")
    private let zone = TimeZone(identifier: "Europe/London") ?? .gmt

    /// Noon on 20 August 2026 in the pinned zone, so nothing here sits near a midnight boundary.
    private let now = Date(timeIntervalSince1970: 1_787_223_600)

    private func event(_ kind: DiagnosticEvent.Kind = .crash, daysAgo: Double,
                       detail: String? = nil, build: String? = nil,
                       system: String? = nil) -> DiagnosticEvent {
        DiagnosticEvent(kind: kind, date: now.addingTimeInterval(-daysAgo * 86_400),
                        detail: detail, appBuild: build, systemVersion: system)
    }

    // MARK: - Retention

    func testKeepsAtMostFiveNewestFirst() {
        let events = (1...9).map { event(daysAgo: Double($0)) }
        let kept = DiagnosticSummary.keeping(events.shuffled(), now: now)
        XCTAssertEqual(kept.count, DiagnosticSummary.retained)
        XCTAssertEqual(kept.map(\.date), events.prefix(5).map(\.date),
                       "Retention must keep the newest five, in order — an older event surviving a "
                        + "newer one describes a build that has already been replaced")
    }

    func testDropsAnythingOlderThanTheRetentionWindow() {
        let stale = event(daysAgo: 91)
        let fresh = event(daysAgo: 89)
        XCTAssertEqual(DiagnosticSummary.keeping([stale, fresh], now: now).map(\.id), [fresh.id])
    }

    func testKeepingAnEmptyListIsEmptyRatherThanAnError() {
        XCTAssertTrue(DiagnosticSummary.keeping([], now: now).isEmpty)
    }

    // MARK: - The bounded line

    func testNoLineWhenThereIsNothingToReport() {
        XCTAssertNil(DiagnosticSummary.line(for: [], now: now, locale: locale, timeZone: zone))
    }

    func testNoLineWhenEverythingHasAgedOut() {
        XCTAssertNil(DiagnosticSummary.line(for: [event(daysAgo: 200)], now: now,
                                            locale: locale, timeZone: zone))
    }

    func testLineNamesTheCountTheOldestDateAndTheNewestDetail() {
        let events = [event(daysAgo: 1, detail: "EXC_BAD_ACCESS", system: "18.2"),
                      event(daysAgo: 5, detail: "SIGTRAP", system: "18.1"),
                      event(daysAgo: 8, detail: "SIGABRT", system: "18.1")]
        XCTAssertEqual(DiagnosticSummary.line(for: events, now: now, locale: locale, timeZone: zone),
                       "3 crashes since 12 Aug · EXC_BAD_ACCESS · iOS 18.2")
    }

    func testASingleEventReadsAsOneOnADateRatherThanSince() {
        let line = DiagnosticSummary.line(for: [event(daysAgo: 2, detail: "SIGSEGV", system: "18.5")],
                                          now: now, locale: locale, timeZone: zone)
        XCTAssertEqual(line, "1 crash on 18 Aug · SIGSEGV · iOS 18.5")
    }

    func testMixedKindsAreCalledProblemsRatherThanNamedAfterTheMajority() {
        let events = [event(.crash, daysAgo: 1), event(.crash, daysAgo: 2), event(.hang, daysAgo: 3)]
        XCTAssertEqual(DiagnosticSummary.line(for: events, now: now, locale: locale, timeZone: zone),
                       "3 problems since 17 Aug")
    }

    func testFreezesAreCalledFreezesNotHangs() {
        let events = [event(.hang, daysAgo: 1), event(.hang, daysAgo: 3)]
        let line = DiagnosticSummary.line(for: events, now: now, locale: locale, timeZone: zone)
        XCTAssertEqual(line, "2 freezes since 17 Aug")
    }

    func testLineOmitsPartsTheOsDidNotProvideRatherThanPrintingBlanks() {
        let line = DiagnosticSummary.line(for: [event(daysAgo: 1)], now: now,
                                          locale: locale, timeZone: zone)
        XCTAssertEqual(line, "1 crash on 19 Aug")
    }

    /// The bound itself. ADR 0161 D3 turned down attaching anything that can't be read in full on one
    /// line; the retention cap is what keeps that true no matter how bad a week the app has.
    func testTheLineStaysOneShortLineEvenAfterManyCrashes() {
        let events = (1...40).map {
            event(daysAgo: Double($0) / 4, detail: "EXC_BAD_ACCESS", system: "18.5")
        }
        let line = DiagnosticSummary.line(for: events, now: now, locale: locale, timeZone: zone)
        XCTAssertEqual(line, "5 crashes since 19 Aug · EXC_BAD_ACCESS · iOS 18.5")
        XCTAssertFalse(line?.contains("\n") ?? true)
    }

    // MARK: - Rows

    func testRowDetailNeverComesBackEmpty() {
        XCTAssertEqual(DiagnosticSummary.rowDetail(for: event(daysAgo: 1), locale: locale,
                                                   timeZone: zone),
                       "19 Aug")
    }

    func testRowDetailCarriesEverythingKnown() {
        let full = event(daysAgo: 1, detail: "SIGTRAP", build: "12", system: "18.5")
        XCTAssertEqual(DiagnosticSummary.rowDetail(for: full, locale: locale, timeZone: zone),
                       "19 Aug · SIGTRAP · build 12 · iOS 18.5")
    }

    func testRowTitleReadsAsASentence() {
        XCTAssertEqual(DiagnosticSummary.rowTitle(for: event(.hang, daysAgo: 1)), "Freeze")
    }

    // MARK: - Naming what the OS reported

    func testNamesTheMachException() {
        XCTAssertEqual(DiagnosticSummary.crashDetail(exceptionType: 1, signal: 11), "EXC_BAD_ACCESS")
    }

    /// The one the app has actually shipped: the `@Sendable` AVAudio tap SIGTRAPped on device and was
    /// invisible on the simulator.
    func testExcCrashDefersToTheSignalBecauseTheWrapperNamesNothing() {
        XCTAssertEqual(DiagnosticSummary.crashDetail(exceptionType: 10, signal: 5), "SIGTRAP")
    }

    func testAnUnknownExceptionKeepsItsNumberRatherThanGuessing() {
        XCTAssertEqual(DiagnosticSummary.crashDetail(exceptionType: 99, signal: nil), "exception 99")
    }

    func testAnUnknownExceptionFallsBackToASignalItDoesKnow() {
        XCTAssertEqual(DiagnosticSummary.crashDetail(exceptionType: 99, signal: 6), "SIGABRT")
    }

    func testNoDetailWhenTheOsGaveNeitherNumber() {
        XCTAssertNil(DiagnosticSummary.crashDetail(exceptionType: nil, signal: nil))
    }

    func testHangDetailRoundsToATenth() {
        XCTAssertEqual(DiagnosticSummary.hangDetail(seconds: 8.238), "froze for 8.2s")
    }

    func testNoHangDetailForANonDuration() {
        XCTAssertNil(DiagnosticSummary.hangDetail(seconds: 0))
    }

    func testShortensTheOsVersionToWhatSettingsShows() {
        XCTAssertEqual(DiagnosticSummary.shortOSVersion("iPhone OS 18.2 (22C152)"), "18.2")
    }

    func testShortOsVersionCopesWithABareNumber() {
        XCTAssertEqual(DiagnosticSummary.shortOSVersion("18.5.1"), "18.5.1")
    }

    func testNoOsVersionRatherThanANonsenseOne() {
        XCTAssertNil(DiagnosticSummary.shortOSVersion("iPhone OS"))
    }
}
