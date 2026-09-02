# ADR 0186 — a reason to come back that isn't a streak

- **Status:** Proposed — nothing built. D1–D7 (the reminder) are the first slice; D8–D12 (the widget)
  are the second and carry an entitlement and a target the first does not. **D5 also names a latent
  bug in shipped code** and should be fixed with the first slice whether or not the rest is built.
- **Date:** 2026-09-01 (`pocket-290-a-reason-to-come-back`)
- **Relates to:** ADR 0070 (no performance feedback — this extends it one level up, from playing to
  habits), ADR 0144 D6 (`TrialReminder` / `TrialReminderPlan` — the pattern both halves copy, the
  app's only existing notification, and the shipped code D5 corrects), ADR 0144 D4 (the Pro wall the
  widget has to answer to), ADR 0113 (account-free, which is why no server-side version of this is
  even possible), ADR 0151 (a take outlives its loop — the lifetime bug D3 is a second instance of),
  ADR 0090 (present by stable identity, which is how D6 routes), ADR 0162 (the Settings hub this
  joins at **Practice**, adding no tenth row), ADR 0163 (settings where you use them — the reminder
  is set on the routine), ADR 0120 / ADR 0147 (analytics, its closed vocabulary and its refusal to
  widen what is collected), ADR 0183 (the bounded-record pattern D9 copies, and the
  `usesSystemNotifications` trap it re-learned), ADR 0182 (backup exclusion for derived data),
  ADR 0148 (`Application Support` as the app's own container), ADR 0044 (the last-practised tempo a
  resume restores), ADR 0117 / ADR 0137 (the practice log this ADR forbids itself from reading)
- **Schema:** none. No `@Model`, no field, no migration, and — decisively — **the SwiftData store does
  not move** (D9). The reminder's schedule is `UserDefaults`; the widget's snapshot is a small JSON
  file in a shared container.

## Context

Red Moon has no notifications beyond the trial reminder, no widget, no App Intents.
`docs/backlog.md:217` logs the gap as *"a reason to come back that isn't a streak"* and names the
danger in one line; this ADR is that entry promoted, because the danger turns out to be the whole
design and it deserves a decision rather than a bullet.

**The default mechanism in this category is absence.** A practice app notices you did not open it and
pings you about it. That is what re-engagement means as it is normally built, and it is what
`docs/positioning.md` §3 defines the product against: **AxeLog** ships streaks, a 12-week heatmap and
an AI report in persona voices; **Yousician** ships levels and streaks. The competitor line is *"you
are scattered, we will fix you."* Ours is *"scattered is normal — here is what makes it add up."*

Three documents make this binding rather than tasteful:

- **ADR 0070** — the app never grades your playing. The player is the sole judge.
- **`docs/design-brief.md` §3.5** — it never grades your *habits* either. *"No streaks, no 'this
  year', no heatmaps, no consistency scores."* And, in as many words: *"No second person past tense
  about failure. Never 'you haven't practised since Tuesday'."*
- **`scripts/check-manual.py` C7** (`PARKED_WORDS`, `:429`) has been failing the build on `streak` and
  `this year` in the manual for months — a tooling guard enforcing the stance before it was written
  down.

The trap is that this reads like a copy problem and is not one. To send an absence-triggered
notification *at all*, the app must first notice you were gone and then act on it. Softening the
wording leaves the mechanism intact, and the mechanism is the thing the three documents forbid. A
gentle "it's been a while!" is the same product decision as a streak counter with better manners.

### What is already true, and what it costs

- **The permission is already exercised.** `Pocket/Core/Monetization/TrialReminder.swift` schedules a
  local notification, so AGENTS.md's *"never add a permission the app doesn't use"* is already
  satisfied. No new permission class — but see D5: sharing a permission with an existing feature is
  not free.
- **There is no push and cannot be.** `Pocket/Resources/Pocket.entitlements` is **empty**, with a
  comment instructing exactly this restraint: *"Do not add entitlements before the feature that needs
  them."* No `aps-environment`, no server, and — with ADR 0113 keeping the app account-free — no
  address to mail. Server-side re-engagement is not declined here; it is **structurally
  unavailable**, which is a stronger guarantee than a promise.
- **Home already solved the framing.** `JumpBackInCard` shows the song you last practised, its
  mastery and when you last touched it, and resumes it at its last-practised tempo (ADR 0044).
  `RecentRoutineCard` shows a routine's name, its block count and how long ago it ran. Both state
  facts and pass no verdict. The re-entry surface exists; it just cannot reach you when the app is
  closed.
- **There is already an `AppDelegate`.** `Pocket/App/OrientationGate.swift:12`, registered via
  `@UIApplicationDelegateAdaptor` at `PocketApp.swift:7`. D6 needs one and does not have to introduce
  it.
- **A widget is a target, not a file** — and, less obviously, an *entitlement* and a **Pro-wall
  decision**. `project.yml` has four targets (`Pocket`, `PocketTests`, `PocketUITests`,
  `PocketShootUITests`) and none is an extension. D9 and D10 are what that costs.

## Decision

**The app never notices your absence. It keeps appointments you made, and shows what is already
true.**

Everything below is that sentence made mechanical, because a principle that lives only in copy review
is one growth-minded pull request away from gone.

### D1 — the only legal trigger is a date the player chose

A notification may fire from a **calendar date the player set**. It may not fire from an inference
about behaviour.

Concretely, and this is the enforceable half: **`PracticeReminderPlan` takes no dependency on
`PracticeLog`, `PracticeRun`, `lastPracticed`, or any recency map.** It is Foundation-only (AGENTS.md,
"pure logic stays pure") and its inputs are the days and time the player picked, plus `now`. The type
that decides whether to send is given no access to whether you practised, so an absence-triggered
notification is not a thing a future author can write here without first widening the signature — a
visible, reviewable act, rather than a one-line condition nobody notices.

This is the same trick ADR 0120 plays with `.swiftlint.yml`: make the wrong thing structurally
awkward rather than merely forbidden.

### D2 — a missed reminder is silent, and that silence is a mechanism

If the reminder fires and the player does not practise, **nothing happens.** No follow-up, no "you
missed yesterday's", no record, no badge, no adjustment to the schedule.

This falls out of D1 rather than being a second rule: the scheduler has no read path to whether an
appointment was kept, so it cannot respond to a missed one even in principle. That is why D1 is
written as a dependency restriction and not as a copy guideline.

**No badge count, ever** (see *Alternatives*). A badge is a tally of things left undone, which is the
absence frame wearing a number.

### D3 — a reminder dies with the thing it points at, and a sweep proves it

A per-routine reminder (D12, ADR 0163) can outlive its routine. `RoutineLibraryView.swift:231` deletes
a routine through `PocketRowDelete`; nothing there knows about notifications. The pending request
survives in the system, fires days later, and opens the app to a routine that no longer exists.

**This is ADR 0151 again** — *a take outlives its loop* — and it is worse in this instance, because
the orphan does not sit quietly in a list waiting to be found. It reaches the player on their lock
screen, outside the app, naming something the app has already forgotten.

So two mechanisms, not one:

1. **The delete path cancels.** Reminder identifiers are derived from `routine.uid`, so cancellation
   needs nothing but the id of the thing being deleted.
2. **Launch reconciles**, and this is the one that actually holds. A cascade delete, a Pro-lapse
   sweep, or a future bulk action can remove a routine without routing through the row-delete
   handler, and `getPendingNotificationRequests` is the only source of truth about what the *system*
   still holds. `PracticeReminder.reconcile` drops any pending request whose `routine.uid` no longer
   resolves — the same shape `TrialReminder.reconcile` already has, for the same reason.

Relying on (1) alone is the version that looks correct in review and fails on a path nobody listed.

### D4 — the pure half holds every decision, and the impure half holds a `Bool`

`PracticeReminderPlan` (pure, unit-tested) decides; `PracticeReminder` (`@MainActor` `@Observable`)
only does what a test cannot. This is ADR 0144 D6 and ADR 0183 D5 for the third time, for the reason
`TrialReminderPlan`'s own header gives: *"every one of the 'don't send this' cases is silent when it
breaks — a reminder that shouldn't have fired looks like nothing at all until it lands on a device."*

Two details are inherited rather than rediscovered:

- **`usesSystemNotifications` is a `Bool` flag, never a stored `UNUserNotificationCenter`.** Holding
  the centre on a `@MainActor` type puts it in the actor's isolation region; the centre is not
  `Sendable` in the SDK CI builds against (Xcode 16) though it is in a newer one, so passing it into
  `requestAuthorization`'s nonisolated context **compiles clean locally and fails CI** with *"sending
  risks causing data races"*. The one `await` that touches the centre is `nonisolated static`.
- **Fixed request identifiers**, one per scheduled weekday, so rescheduling *replaces* rather than
  stacking a second copy behind it — the rule `TrialReminder.requestIdentifier` already states.

The trigger is a repeating `UNCalendarNotificationTrigger` on `DateComponents(hour:minute:weekday:)`.
A repeating request counts **once** against iOS's 64-request ceiling however often it fires, so seven
weekdays is seven requests, and there is no rolling re-arm to get wrong.

### D5 — read the authorization status before asking, and fix the paywall that doesn't

Asked at the moment the player sets a reminder, permission is part of the thing they just requested.
Asked at launch or on first run it reads as *"we would like to send you things"*, and gets denied
once, permanently. That much is `TrialReminder.requestAuthorization`'s documented rule.

**What that rule does not cover, and what would ship broken:** the system prompt appears **once, ever,
for the app** — not once per feature. Apple states it plainly: *"Because the system saves the user's
response, calls to this method during subsequent launches do not prompt the user again."* After a
denial, `requestAuthorization` returns `false` immediately and shows nothing. There is no API to
re-present the prompt; the only route back is the Settings app.

Two features now share that one-shot prompt, and the failure is symmetric:

- `PaywallView.reminderBinding` (`:203`) calls `requestAuthorization` when the trial toggle is
  switched **on**, and `TrialReminder.requestAuthorization` assigns `remindersEnabled = granted`. So
  on a prior denial the toggle **flips visibly back off with no explanation given** — its own doc
  comment says *"a denial turns it straight back off"*, which is correct behaviour for a fresh
  denial and misleading for a remembered one.
- A practice reminder set later behaves identically, for the same reason.

And the likelier ordering is the one the first draft of this ADR missed. A practice reminder is
something many players set early; the paywall is seen by fewer, later. **So the more common path is a
denial at the practice reminder silently breaking the trial toggle** — the one with revenue attached.

The decision, therefore, covers both:

**Before calling `requestAuthorization`, read `notificationSettings().authorizationStatus`.** On
`.notDetermined`, ask. On `.denied`, do not ask — say the permission is off and offer
`UIApplication.openSettingsURLString`. On `.authorized` or `.provisional`, proceed without asking.

This is a **bug fix to shipped code**, not new-feature scaffolding, and it stands on its own if the
rest of this ADR is never built. It is also why `remindersEnabled` must stop doubling as "notifications
are on" generally (see *Consequences*).

**The half that needs no permission is always present.** A denied reminder still leaves the schedule
visible on the routine — the same split that keeps the trial *countdown* working when the trial
*notification* is refused.

### D6 — the tap lands on the routine, routed by `uid`

A notification whose tap opens Home has wasted the only interaction it gets. `TrialReminder` sets no
`UNUserNotificationCenterDelegate` because it is purely informational; a practice reminder is not, and
needs one.

The delegate must be set **before the app finishes launching**, which is exactly what the existing
`@UIApplicationDelegateAdaptor` at `PocketApp.swift:7` provides — so this hangs off
`OrientationGate.swift`'s `AppDelegate` rather than introducing a second one. That file gains a
responsibility unrelated to orientation, which is a real (small) cost and should be noted in its
header rather than left as a surprise.

The request's `userInfo` carries the routine's **`uid`**, never its `persistentModelID` — ADR 0090 and
`docs/swiftdata-gotchas.md`. A `PersistentIdentifier` is not stable across the store's lifetime and is
the wrong thing to put in a payload that outlives a launch.

A tap that resolves nothing opens Home and says nothing. That is D3's failure mode after the sweep has
been missed, and it must degrade quietly rather than trap.

### D7 — copy is future tense, names the material, and never narrates the player

> **Morning warm-up** · 4 blocks

Not *"Time to practise!"*, not *"Don't lose your progress"*, and never a second person past tense
about failure. The notification says what is waiting, the way the routine's own card says it.

`internal_name_in_user_copy` already applies to every literal here — the app is **Red Moon**.
`docs/manual/` gains a page, and `check-manual.py` C7 will fail the build if that page reaches for
`streak` while explaining what the reminder is not.

**Proposed, not decided: a third custom lint rule.** `.swiftlint.yml`'s two existing custom rules both
exist because the thing they catch *already shipped*. Notification copy is the surface most exposed to
future growth pressure and the least likely to be re-read, which is the profile those rules are for. A
rule matching second-person-past-failure constructions in `UNMutableNotificationContent` copy is the
natural third. Left as a proposal because, unlike the other two, this one has no incident behind it
yet — and a regex over English is a worse instrument than a regex over `AnalyticsEvent` cases.

### D8 — the widget is the same feature with the interruption removed, and it ships second

A widget cannot notice your absence either — it has no trigger at all. It sits there and states what
is next. It is **pull, not push**, which makes it the purer expression of everything above: no
permission, no interruption, nothing to deny, and no moment at which the app decides you need
speaking to.

It ships second only on cost. D9 and D10 are why.

### D9 — the widget reads a bounded snapshot; the SwiftData store does not move

This is the decision that matters, and the one that would have been made badly by default.

A widget extension is a **separate process with its own container**. `PocketApp.swift:84` builds the
container with `.modelContainer(for: [...])` and no explicit `ModelConfiguration`, so the store is at
the default `Application Support/default.store` **inside the app's own container**, where an extension
cannot read it. The obvious route — an App Group plus `ModelConfiguration(url:)` pointing into the
shared container — means **relocating a live store on every installed device**, during a closed beta,
against a schema deliberately frozen for the 1.1 review, to power a widget. The migration has no good
failure mode: a store that fails to move is a player's entire practice history.

So the store stays where it is, and **the app writes the widget a small JSON snapshot** into the
shared container whenever the thing it shows changes, then calls
`WidgetCenter.shared.reloadTimelines(ofKind:)`. The widget target links no SwiftData, imports no
`@Model` type, and reads one file it could not corrupt if it tried.

This is `DiagnosticsStore` again (ADR 0183) — *"a small JSON file in Application Support"* — and it
carries 0183 D1's discipline for the same reason: the snapshot holds **only what the widget renders**.
A snapshot that carried history would put the practice log in a second process that D1 has no
jurisdiction over. Bounding it is what makes D1's invariant travel across the process boundary.

An App Group entitlement is still required, and it is the first entry in a file whose comment says not
to add one before the feature that needs it. That comment is satisfied here: the group *is* the
feature, and it is added with it, not ahead of it.

**The snapshot is derived data and is excluded from backup unconditionally** — ADR 0183 D7's rule, not
ADR 0182 D3's toggle. Nobody misses a restored widget cache, and it is rebuilt on the next launch.

### D10 — the widget draws the Pro wall, and the snapshot carries the entitlement

Every re-entry surface on Home is gated: `JumpBackInCard` routes through `proGated(.song)`,
`RecentRoutineCard` through `proGated(.routine)`, and both take `locked: !isPro`
(`HomeView.swift:76-79`, `:347-350`). ADR 0144 D4 made that lock **visible** rather than silent,
because the rail *"was the one door on Home that looked open while it wasn't."*

A widget is a fifth door, on the home screen, in a process where `proGated` does not exist. Left
unaddressed it is 0144 D4's bug again, one surface further out.

So: **the snapshot carries the entitlement state, and the widget renders the same
inviting-but-locked grammar Home does** — the material still named, the lock glyph present, the tap
opening the paywall. Not blank (which reads as broken) and not open (which lies).

**The snapshot must be rewritten when entitlement changes**, or a lapsed subscriber keeps a Pro widget
indefinitely. The hook exists: `PocketApp.swift:79-81` already calls `refreshEntitlements()` on
`scenePhase == .active` precisely because *"iOS suspends apps for days, so the stale window is not a
moment."* That comment was written about the trial countdown and applies verbatim here.

### D11 — the widget says what Home already says

`JumpBackInCard`'s grammar, on the home screen: the material, its size, and — yes — when it was last
practised.

**A relative date is permitted; a verdict is not.** `docs/design-brief.md` §3.5 draws the line
exactly there: *"Numbers may be shown; they may not be judged. A tempo, a run count and a date are
facts. 'On track', 'behind', 'your best week' are verdicts."* `RecentRoutineCard` ships
`localizedString(for:relativeTo:)` today and is not in breach. What is forbidden is the count of days
*missed*, the streak, the heatmap, and any of it used as a **trigger**.

The distinction is worth stating because it is the one a reviewer will get wrong in both directions.

### D12 — it joins Settings at **Practice**, and the hub does not grow

ADR 0162 D2 groups the hub by *"what am I trying to change?"* — a reminder changes how you practise,
so it belongs on the existing **Practice** destination. Per ADR 0163, the per-routine reminder is set
**on the routine**, where you are using it, with the global default in Settings. The hub keeps its ten
rows and `check-manual.py`'s C1 count is untouched.

## Alternatives considered

**Absence-triggered re-engagement** — *"You haven't practised in 3 days."* Rejected outright, and the
reason is the whole ADR: it requires the app to notice and act on your absence, which ADR 0070 and
design-brief §3.5 forbid. This is the alternative every other app in the *practice organisers* cohort
chose.

**A streak, or a streak-at-risk warning.** Rejected. Named explicitly in design-brief §3.5 and
enforced by `check-manual.py` C7. It is also the single loudest thing AxeLog does, so shipping it
would be the product arguing against its own positioning.

**A weekly or annual summary — "your week in practice", a wrapped.** Rejected. ADR 0117 already
deferred the journal year tier, and a summary is a verdict wearing statistics: it cannot be assembled
without an implicit "good week / bad week" axis, and the interesting cell is always the empty one.

**A badge count.** Rejected per D2. A badge is a running tally of things you have not done, displayed
on the app icon, permanently. It is the absence frame with no copy to soften.

**Push notifications from a server.** Rejected, and unavailable: ADR 0113 keeps the app account-free
so there is no addressee, and the entitlements file carries no `aps-environment`. Recorded so the
absence is a decision rather than an oversight.

**Provisional authorization** (`.provisional`, quiet delivery with no prompt). Rejected. It would
sidestep D5's one-shot prompt entirely, which is precisely its problem: a reminder the player never
consciously agreed to is the app deciding to reach them, and D5's whole point is that they asked.

**Share the SwiftData store with the widget via an App Group.** Rejected per D9 — a live store
relocation on every installed device, mid-beta, to render one line of text. The snapshot gets the same
result with no migration and no SwiftData in a second process.

**`UserDefaults(suiteName:)` instead of a JSON file** for the snapshot. Reasonable, and lighter. Not
chosen, for consistency with `DiagnosticsStore` and because a file takes the backup-exclusion resource
value that D9 wants; a defaults suite does not, cleanly.

**Ship the widget first, or instead of the reminder.** Genuinely considered — D8 argues it is the
purer expression of the value, and an app whose *only* re-entry surface never interrupts anyone would
be a defensible product. Rejected as the first slice on cost alone (a new target, an entitlement, a
Pro-wall decision, and manual code-signing churn, against a reminder that is two Foundation types),
and **not** rejected as a feature. If only one of the two is ever built, it should be the widget.

**A Live Activity during a running practice session.** Deferred, not rejected — and it is the most
values-safe form of all three, because it reports something that is *happening now* and ends when the
session does. It cannot notice absence because it only exists during presence. Worth its own ADR when
the session model is next opened.

**App Intents / Siri — "start my warm-up".** Deferred. Also pull, also values-safe, and it shares the
snapshot D9 introduces. Out of scope here to keep the entitlement decision to one target.

## Consequences

**D5 is a fix to shipped code and should not wait for the rest.** The paywall's trial toggle can
already flip silently back off for any player who has denied notifications, and today nothing in the
app reads `authorizationStatus` at all. That is live in the closed beta.

**`remindersEnabled` must stop standing for "notifications are on".** It is currently one flag written
from the authorization result (`TrialReminder.swift:90`), so it conflates *this feature is wanted*
with *the app has permission*. Two features need those separated: turning off the practice reminder
must not cancel the trial reminder, and vice versa. Distinct fixed identifiers make the *scheduling*
independent; the flag is what makes the *intent* independent.

**A repeating calendar trigger follows the device's timezone, which is right, and DST, which is
mostly right.** A weekly 08:00 reminder fires at 08:00 wherever the player wakes up — correct for
practice. The exception is a time that does not exist on the spring-forward day, which does not fire
that week. Not worth engineering around; worth not being surprised by.

**The widget adds a target to every build.** Pre-push and CI both grow an extension compile, and
`scripts/docs-only.sh` is unaffected (this ADR is docs-only; the build is not). The shoot harness
(ADR 0165 Phase 5) cannot photograph a home-screen widget from a UI test — widgets live in SpringBoard,
not in the app under test — so the manual page needs a hand-taken figure or none. Decide that before
the page is written, not after.

**Manual code signing pays for the App Group.** `project.yml` sets `CODE_SIGN_STYLE: Manual`, so the
group must be registered in the developer portal and **both** provisioning profiles regenerated
before the extension will install on a device. That is a step the last several ADRs did not have, and
it will fail the first device build.

**Docs that move with this when it is built:** `CHANGELOG.md`, `PROJECT.md` (a new service and, for
the widget, a new target and entitlement), `docs/architecture.md` (the `TrialReminder` module note
grows a sibling; its *"Local notifications only — no `aps-environment`"* line stays true and should
say so louder), `docs/manual/` (a control on the routine screen and a Settings row), `README.md` (the
target list), and `docs/design-brief.md` if D7's copy rule graduates into the voice section.

**`docs/backlog.md:217` is superseded by this file** and should point at it rather than restating it.

**Nothing here is proven by a green simulator run.** A repeating calendar trigger cannot be usefully
driven from a test — the same wall `TrialReminderPlan` hit, and the reason
`docs/plans/storekit-sandbox-validation.md:280` records the trial reminder as *not testable in
sandbox*. `PracticeReminderPlan` carries every assertion; delivery is verified on device. Two things
in particular need a device and patience: **D2's absence of a follow-up**, which is verified by
deliberately missing a reminder and *waiting*, and **D3's orphan sweep**, which is verified by
scheduling a reminder, deleting its routine, and leaving the app closed until the fire date.
