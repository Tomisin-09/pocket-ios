# ADR 0156 — a paywall you can predict

- **Status:** Proposed — not built, not device-verified. See *Consequences* for why it cannot be verified yet.
- **Date:** 2026-08-11
- **Supersedes:** ADR 0144 **D4**, narrowly — the "once per launch" clause only. Every other part of D4 (gate at the Home destinations, cards locked-not-hidden) stands unchanged.
- **Builds on:** ADR 0112 (gate at read time; `AccessPolicy` as the one seam; nothing about Pro persisted) · ADR 0144 (one app, one price, evaluated through a free trial) · ADR 0120 (the paywall host is the one place that reports a gate firing)
- **Relates to:** ADR 0113 (the first-run intake wins the screen)

## Context

The note that prompted this asked for the paywall's events and timings during the **free trial** to
be specific and carefully managed — "I don't want users feeling like the next pop up is crawling
around the corner."

**During an active trial the paywall never appears. Not once.** A StoreKit introductory offer *is* an
entitlement, so `Transaction.currentEntitlements` returns the product, `StoreManager.isPro` is
`true`, and both the launch wall and all ~18 gates are skipped by the same `isPro` check. The only
monetisation UI a player in their trial month ever sees is `TrialCountdownRow` on Home and in
Settings, and the opt-in local notification 24 hours before the trial ends (ADR 0144 D6). There is no
in-trial pop-up, and nothing here changes that.

The feeling the note describes is real. It is just aimed one phase early: **it belongs to the player
who has not started a trial yet.**

For that player, three facts compose badly.

**The launch wall's throttle is per process, not per player.** ADR 0144 D4 says "once per launch",
and `PaywallHost` implements it exactly — `@State private var launchWallShown`, deliberately not
`@AppStorage`, with a comment arguing (correctly) that a permanently-dismissible wall is invisible
after day one. But "once per launch" prices a launch as if it were a day. Someone who opens the app
to tune, closes it, opens it after dinner to run a scale, closes it, opens it again before bed meets
three full-screen walls in one evening — each of them technically obeying the rule.

**No gate is throttled at all.** Around eighteen call sites raise a paywall on tap —
`HomeView+Actions.swift:27`, `RoutineLibraryView.swift` at five separate actions,
`ExerciseTemplatePicker.swift:67`, `JournalTabView.swift:155` and `:160`, and the rest. Every one
fires every time. There is no seen-flag, no cooldown, no session-once guard. Dedupe exists only
*within* a presentation: `PaywallTrigger.id` folds detail into identity so a different intent
re-presents rather than being swallowed by `.sheet(item:)`.

**Nothing anywhere remembers that a paywall was shown.** `AppSettings.Key` has `artistIntakeSeen`,
`artistNamePromptSeen` and `analyticsPromptSeen`; there is no paywall equivalent. `AccessPolicy`
answers *may they* and has no knowledge of time, trial state or presentation history — by design, and
that character is worth keeping. `PaywallHost` is the only type in the app that knows a paywall went
up, and its memory dies with the process.

So there is no single place that answers "should we show the paywall now?" The question has never
been asked; only "is this locked?" has.

### The distinction the code already half-knows

`PaywallTrigger.launch` carries this doc comment:

> Not reached for — **it comes to them** — which is why it is its own trigger rather than `.general`:
> a dismissal here is a very different signal from dismissing a wall you walked into.

That is the whole decision, already written down and not yet acted on. A gate paywall is an
**answer**: the player tapped a locked thing, and the app explained why it did not open. The launch
wall is **unsolicited**: nobody asked, and it is the only thing in the app that interrupts without
being asked.

Those two deserve opposite treatment. Capping an answer would leave a dead tap — the worst outcome
available, because the player now has a control that silently does nothing. Not capping an
interruption is what produces the crawling-around-the-corner feeling.

## Decision

### 1. Unsolicited presentations get a budget. Solicited ones never do.

A paywall raised because the player touched a locked thing is **uncapped, unchanged, and stays that
way**. This is stated as a rule, not left as an omission, so that a later reader tidying up
"inconsistent" throttling does not remove the one behaviour that must not be removed. If a gate can
decline to present, the tap becomes dead, and a dead tap is a bug that looks like a policy.

Only `.launch` — the one trigger that comes to the player rather than from them — is budgeted.

### 2. One pure type owns the question

`PaywallPresentationPolicy`, in `Pocket/Core/Monetization/`, alongside `AccessPolicy` and
`PaywallTrigger`. Foundation-only, no `StoreManager`, no SwiftUI, no `UserDefaults` — every input
passed in, in the shape `TrialReminderPlan.decide` already established for a decision that had to be
testable without a store:

```swift
struct PaywallPresentationPolicy {
    struct State {
        var lastUnsolicitedShownAt: Date?
        var unsolicitedShownCount: Int
        var lastDismissedAnyAt: Date?
    }

    static func mayShowUnsolicited(state: State,
                                   isPro: Bool,
                                   hasResolvedEntitlements: Bool,
                                   artistIntakeSeen: Bool,
                                   now: Date) -> Bool
}
```

It answers one question and holds no state of its own. `PaywallHost` reads and writes the persisted
`State`; the policy just decides.

`AccessPolicy` is deliberately **not** extended to cover this. It answers *may they* and knows
nothing of time or presentation history; giving it a clock would change what kind of thing it is, and
ADR 0144 D3 kept it as the single entitlement seam precisely because it stayed that narrow.

### 3. Three rules, and they are the whole policy

Given `!isPro`, `hasResolvedEntitlements`, and `artistIntakeSeen` — all three already required today
and all three retained:

1. **A dismissal buys quiet.** No unsolicited paywall within **24 hours** of the player dismissing
   *any* paywall, gate or wall. This is the rule that does the work the note asked for. A player who
   just said "not now" to a gate does not get walled on the next launch, and the two surfaces stop
   compounding each other.
2. **The wall has a rhythm.** At most one unsolicited presentation per **72 hours**.
3. **The rhythm slows when the answer is clear.** From the **fourth** unsolicited presentation
   onward, the interval widens to **7 days**. Three no's is enough information; a player who has
   declined the wall three times is not going to be persuaded by a fourth at the same cadence, and
   continuing at that cadence is what turns a pitch into nagging.

Rules 2 and 3 both apply; the effective interval is the wider of the two. Nothing resets the count
except becoming Pro, at which point the whole policy is moot.

The numbers are stated here rather than left to the implementation because they *are* the decision.
"Carefully managed" is not a property of the code; it is a property of these three integers, and they
belong in the record where they can be argued with.

### 4. The state persists, and it is allowed to be lost

Three new `AppSettings.Key` entries — `paywallLastUnsolicitedShownAt`,
`paywallUnsolicitedShownCount`, `paywallLastDismissedAnyAt` — in `UserDefaults` beside the other
`*Seen` flags. Nothing goes in the SwiftData store: this is presentation history, not practice
history, and ADR 0112's "nothing about Pro is persisted" rule is about *entitlement*, which this is
not.

Losing it on reinstall is acceptable and is not worth defending against. A reinstalling player
getting one wall is the correct outcome anyway.

Clock changes are not defended against either. A player who moves their clock backwards gets a longer
quiet window than the policy intends, which errs in the direction this ADR is arguing for; forwards,
and they get one extra wall. Neither is worth a monotonic clock.

### 5. Dismissal is recorded at both existing seams

`PaywallHost` already has `reportDismissal` and `reportLaunchWallDismissal`, both of which fire
analytics. Both gain one line writing `paywallLastDismissedAnyAt`. Because a *purchase* also closes
the sheet, the write is skipped when the presentation converted — the existing `wasProAtPresent`
comparison already distinguishes "became Pro during this presentation" from "was Pro all along", so
no new signal is needed.

### 6. Nothing about the trial changes

No in-trial paywall is added, because there isn't one to manage. `TrialCountdownRow` and the 24-hour
notification remain exactly as ADR 0144 D6 specified them, and remain the only monetisation UI a
player in their trial month meets. If a future ADR wants a trial-end conversion moment, it is a new
decision and belongs in its own record — this one deliberately leaves the trial alone.

## Consequences

- **`maybeShowLaunchWall()` stops being the throttle and becomes a caller.** It keeps its two
  existing guards (`hasResolvedEntitlements`, `artistIntakeSeen`) — the first because `isPro` is
  `false` until the async scan lands and the wall would otherwise flash at every paying subscriber on
  every launch, the second because ADR 0113's first-run intake must win the screen. The per-process
  `launchWallShown` flag stays as well: it guards against re-entry *within* one launch, which the
  time-based policy would also permit but which nothing should rely on.
- **This cannot be verified on TestFlight.** The in-flight closed-beta grant makes Release+sandbox
  builds Pro outright, so no tester will meet a paywall at all. `docs/plans/beta-testing-plan.md`
  already accepts this explicitly — *"this round learns nothing about paywall reaction. That is a
  separate round."* Verification is local: a StoreKit configuration file with `debugProOverride` set
  to `false`, plus the pure unit tests, which are the substance of the change. **This ADR should not
  move to Accepted until the beta Pro grant is removed and it has been run against a real
  non-entitled build.**
- **The unit tests are the real deliverable.** `PaywallPresentationPolicyTests` covers the
  boundaries: exactly at 24h and 72h, the 3→4 widening, a dismissal inside an otherwise-eligible
  window, and the three preconditions each independently blocking. None of it needs a simulator.
- **Analytics gain a silence they cannot see.** `.paywallShown(trigger: .launch)` will fire less
  often, and there is no event for "the policy declined to show". If the launch-wall conversion rate
  moves, it will be impossible to tell from the data whether fewer walls converted better or simply
  converted the same and were counted less. Accepted for now — ADR 0120's event enum is closed on
  purpose and this does not clear the bar for opening it — but noted, because it is the first
  question anyone will ask of the numbers.
- **A player can now go days without seeing the offer.** That is the point, and it is a real
  trade against conversion. The mitigation is that the gates are untouched: someone actually trying
  to use the app still meets the paywall the moment they reach for something locked, which is both
  more frequent and better timed than the wall ever was.

## Alternatives considered

**Persist the once-per-launch flag as `@AppStorage`.** The obvious small fix, and the one
`PaywallHost.swift:19-22` already argues against: a permanently-dismissible wall is invisible after
day one. Rejected for the same reason it was rejected then. The problem was never that the flag was
in memory; it was that "per launch" is the wrong unit.

**Cap the gates too, for consistency.** Rejected in §1. A gate that declines to present leaves a tap
that does nothing, and the player's model of the app breaks in a way no amount of restraint pays for.

**Show the wall once, ever, then rely on gates alone.** Clean, and tempting. Rejected because it
gives up the one honest use the wall has: a player who has drifted for a fortnight without touching a
locked surface has genuinely not been told what the app costs. The decaying interval in §3 is the
compromise — it approaches "once, ever" asymptotically without committing to it on day one.

**Make the interval depend on engagement rather than time** — wall them after N practice sessions
rather than N days. Better targeted in principle: it pitches to someone using the app rather than
someone merely opening it. Rejected as premature. It needs a definition of "session" that the
monetisation layer does not currently have, and it couples the paywall to the practice log for a
gain nobody has yet measured. Worth revisiting if the time-based version proves too blunt.

**Put the decision in `AccessPolicy`.** Rejected in §2 — it would give a pure entitlement predicate a
clock, and ADR 0144 D3 kept that type narrow on purpose.
