import XCTest
@testable import Pocket

/// The pure click-withdrawal cycle (ADR 0132). This is bar arithmetic that decides whether a click
/// sounds, so it fails **silently** — a wrong origin or an off-by-one in the bar index doesn't crash
/// or warn, it just puts the silence somewhere musically meaningless and the feature reads as "feels
/// wrong". Exhaustive by intent (AGENTS.md): the level at every bar of every cycle, the count-in
/// boundary, and the resolution table.
final class ClickWithdrawalTests: XCTestCase {

    /// The levels of one full cycle, bar 0 through 7, at a given tier.
    private func cycle(_ withdrawal: ClickWithdrawal) -> [ClickWithdrawal.Level] {
        (0..<ClickWithdrawal.cycleBars).map { withdrawal.level(atBar: $0) }
    }

    // MARK: the three distributions (§2)

    func testGentleThinsOnlyTheLastBarPair() {
        XCTAssertEqual(cycle(.gentle),
                       [.full, .full, .full, .full, .full, .full, .downbeatOnly, .downbeatOnly])
    }

    func testStandardThinsThenSilences() {
        XCTAssertEqual(cycle(.standard),
                       [.full, .full, .full, .full,
                        .downbeatOnly, .downbeatOnly, .silent, .silent])
    }

    func testDeepWithdrawsForHalfTheCycle() {
        XCTAssertEqual(cycle(.deep),
                       [.full, .full, .downbeatOnly, .downbeatOnly,
                        .silent, .silent, .silent, .silent])
    }

    func testOffNeverWithdraws() {
        XCTAssertEqual(cycle(.off), Array(repeating: .full, count: ClickWithdrawal.cycleBars))
    }

    /// **Every cycle starts full** (§2) — you cannot withdraw a pulse that was never established, so
    /// the start of a run always sounds normal whatever the tier.
    func testEveryTierOpensFull() {
        for withdrawal in ClickWithdrawal.allCases {
            XCTAssertEqual(withdrawal.level(atBar: 0), .full, "\(withdrawal) must open full")
            XCTAssertEqual(withdrawal.level(atBar: 1), .full, "\(withdrawal) must open full")
        }
    }

    /// The cycle repeats forever, so the return is always in the same place and can be anticipated.
    func testTheCycleRepeatsEveryEightBars() {
        for withdrawal in ClickWithdrawal.allCases {
            for bar in 0..<24 {
                XCTAssertEqual(withdrawal.level(atBar: bar),
                               withdrawal.level(atBar: bar + ClickWithdrawal.cycleBars),
                               "\(withdrawal) bar \(bar) must repeat a cycle later")
            }
        }
    }

    // MARK: the bar index (§8)

    func testBarIndexCountsFromTheDrillOrigin() {
        // 4/4, no subdivision: four ticks to the bar, counted from the first musical downbeat.
        let bar = { ClickWithdrawal.barIndex(forTick: $0, originTick: 8,
                                             ticksPerBeat: 1, beatsPerBar: 4) }
        XCTAssertEqual(bar(8), 0, "the origin itself is bar 0")
        XCTAssertEqual(bar(11), 0)
        XCTAssertEqual(bar(12), 1)
        XCTAssertEqual(bar(40), 8, "one cycle on")
    }

    /// A tick before the origin sits at a **negative** bar index and must stay there. Integer division
    /// truncates toward zero, which would fold the bar before the cycle onto bar 0 and let the opening
    /// bar inherit a withdrawn level — so the index floors explicitly.
    func testTicksBeforeTheOriginFloorToNegativeBars() {
        let bar = { ClickWithdrawal.barIndex(forTick: $0, originTick: 8,
                                             ticksPerBeat: 1, beatsPerBar: 4) }
        XCTAssertEqual(bar(7), -1, "the last count-in tick is the bar before the drill")
        XCTAssertEqual(bar(4), -1)
        XCTAssertEqual(bar(3), -2)
    }

    func testBarIndexHonoursSubdivisionAndMeter() {
        // Sixteenths in 3/4: four ticks a beat, twelve to the bar.
        XCTAssertEqual(ClickWithdrawal.barIndex(forTick: 11, originTick: 0,
                                                ticksPerBeat: 4, beatsPerBar: 3), 0)
        XCTAssertEqual(ClickWithdrawal.barIndex(forTick: 12, originTick: 0,
                                                ticksPerBeat: 4, beatsPerBar: 3), 1)
    }

    // MARK: where the cycle starts counting (§8)

    /// The cycle must begin on a **bar downbeat**, because eligibility can begin mid-bar — the tier is
    /// switched on while the click runs, or a ramp that suspended it stops. Starting bar 0 wherever
    /// that landed would offset every later silent bar from the music by a fraction of a bar.
    func testTheOriginRoundsUpToTheNextDownbeat() {
        // 4/4, no subdivision ⇒ four ticks to the bar.
        let origin = { ClickWithdrawal.originTick(eligibleAt: $0, ticksPerBeat: 1, beatsPerBar: 4) }
        XCTAssertEqual(origin(0), 0, "already on a downbeat — start here")
        XCTAssertEqual(origin(4), 4)
        XCTAssertEqual(origin(5), 8, "mid-bar waits for the next downbeat")
        XCTAssertEqual(origin(7), 8)
    }

    func testTheOriginHonoursSubdivisionAndMeter() {
        // Eighths in 3/4 ⇒ six ticks to the bar.
        XCTAssertEqual(ClickWithdrawal.originTick(eligibleAt: 7, ticksPerBeat: 2,
                                                  beatsPerBar: 3), 12)
    }

    // MARK: the per-tick verdict (§1, §4)

    func testAFullBarLeavesEveryTickUnchanged() {
        let verdict = ClickWithdrawal.deep.verdict(forTick: 5, originTick: 0,
                                                   ticksPerBeat: 1, beatsPerBar: 4)
        XCTAssertEqual(verdict, .unchanged, "bar 1 is full at every tier")
    }

    func testADownbeatOnlyBarSoundsItsFirstTickAndNothingElse() {
        // Deep, bar 2: eighths in 4/4 ⇒ eight ticks to the bar, ticks 16…23.
        let bar2 = 16
        XCTAssertEqual(ClickWithdrawal.deep.verdict(forTick: bar2, originTick: 0,
                                                    ticksPerBeat: 2, beatsPerBar: 4), .downbeat)
        for offset in 1..<8 {
            XCTAssertEqual(ClickWithdrawal.deep.verdict(forTick: bar2 + offset, originTick: 0,
                                                        ticksPerBeat: 2, beatsPerBar: 4), .silent,
                           "only beat 1 survives a downbeat-only bar")
        }
    }

    func testASilentBarSchedulesNothing() {
        for offset in 0..<4 {
            XCTAssertEqual(ClickWithdrawal.deep.verdict(forTick: 16 + offset, originTick: 0,
                                                        ticksPerBeat: 1, beatsPerBar: 4), .silent)
        }
    }

    /// Ticks before the cycle's origin are never withdrawn — the click sounds normally right up to
    /// the downbeat the cycle starts on.
    func testTicksBeforeTheOriginAreNeverWithdrawn() {
        for tick in 0..<4 {
            XCTAssertEqual(ClickWithdrawal.deep.verdict(forTick: tick, originTick: 4,
                                                        ticksPerBeat: 1, beatsPerBar: 4), .unchanged)
        }
    }

    func testOffHasNothingToSayAboutAnyTick() {
        for tick in 0..<64 {
            XCTAssertEqual(ClickWithdrawal.off.verdict(forTick: tick, originTick: 0,
                                                       ticksPerBeat: 1, beatsPerBar: 4), .unchanged)
        }
    }

    // MARK: resolution (§4, §6)

    /// Resolution on the metronome tool with a steady click — the one case where a tier applies.
    private func resolved(_ exercise: String?, _ global: ClickWithdrawal) -> ClickWithdrawal {
        ClickWithdrawal.resolve(exercise: exercise, global: global, onMetronomeTool: true,
                                rampRunning: false, strumArmed: false)
    }

    func testNilExerciseInheritsTheGlobalDefault() {
        // `nil` means *inherit* and can never be collapsed into `off` — otherwise the stored tier
        // silently becomes a new-exercises-only preference.
        XCTAssertEqual(resolved(nil, .standard), .standard)
        XCTAssertEqual(resolved(nil, .off), .off)
    }

    func testAnExercisePinnedOffOverridesAGlobalLevel() {
        XCTAssertEqual(resolved("off", .deep), .off,
                       "a drill that keeps its click must survive turning withdrawal on")
    }

    func testAnExerciseLevelOverridesTheGlobal() {
        XCTAssertEqual(resolved("gentle", .off), .gentle)
        XCTAssertEqual(resolved("deep", .gentle), .deep)
    }

    func testAnUnrecognisedOverrideInherits() {
        XCTAssertEqual(resolved("twoOnTwoOff", .standard), .standard)
    }

    /// **The free-play metronome only** (§4, as amended 2026-08-05). Withdrawal is opt-in per host, so
    /// a screen that gains a metronome later can't inherit it by accident.
    func testAHostThatDoesNotOfferItNeverWithdraws() {
        XCTAssertEqual(ClickWithdrawal.resolve(exercise: nil, global: .deep, onMetronomeTool: false,
                                               rampRunning: false, strumArmed: false), .off)
        XCTAssertEqual(ClickWithdrawal.resolve(exercise: "deep", global: .deep, onMetronomeTool: false,
                                               rampRunning: false, strumArmed: false), .off,
                       "an explicit level can't opt a host in — the exclusion is a rule, not a taste")
    }

    /// **The click withdraws when it is a steady click.** A moving tempo and a withdrawing click are
    /// two demands at once, and a click that leaves during a climb removes the reference exactly as
    /// the thing to measure against changes.
    func testARunningRampSuspendsWithdrawal() {
        XCTAssertEqual(ClickWithdrawal.resolve(exercise: nil, global: .deep, onMetronomeTool: true,
                                               rampRunning: true, strumArmed: false), .off)
    }

    /// An armed strum pattern excludes withdrawal outright (§4): the pattern's rhythm is the lesson,
    /// not the scaffolding, so silencing it removes the exercise rather than a crutch. Unreachable
    /// while the host gate stands, and kept because Slice 2's override could put it back in reach.
    func testAnArmedStrumPatternExcludesWithdrawal() {
        XCTAssertEqual(ClickWithdrawal.resolve(exercise: nil, global: .deep, onMetronomeTool: true,
                                               rampRunning: false, strumArmed: true), .off)
    }

    // MARK: the caption (§7)

    func testOnlyAWithdrawnBarHasSomethingToSay() {
        XCTAssertNil(ClickWithdrawal.Level.full.caption)
        XCTAssertNotNil(ClickWithdrawal.Level.downbeatOnly.caption)
        XCTAssertNotNil(ClickWithdrawal.Level.silent.caption)
    }

    // MARK: the stored setting (§5)

    func testUnsetWithdrawalTakesOff() {
        XCTAssertEqual(AppSettings.resolvedClickWithdrawal(storedValue: nil), .off)
    }

    func testSetWithdrawalReadsItsStoredValue() {
        XCTAssertEqual(AppSettings.resolvedClickWithdrawal(storedValue: "gentle"), .gentle)
        XCTAssertEqual(AppSettings.resolvedClickWithdrawal(storedValue: "deep"), .deep)
    }

    func testUnrecognisedWithdrawalFallsBackToOff() {
        // The failure mode of a silent click is worse than a click that keeps sounding, so an
        // unreadable value degrades toward the audible end.
        XCTAssertEqual(AppSettings.resolvedClickWithdrawal(storedValue: "fourBarGap"), .off)
    }
}
