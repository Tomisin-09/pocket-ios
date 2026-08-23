# ADR 0183 — a crash that reaches us

- **Status:** Accepted
- **Date:** 2026-08-23 (`pocket-285-a-crash-that-reaches-us`)
- **Relates to:** ADR 0161 (the in-app contact form this feeds, **D3 in particular**), ADR 0120
  (analytics, its opt-in and its four privacy artefacts), ADR 0147 (inform-and-object, and its
  refusal to widen what is collected), ADR 0144 D6 (`TrialReminder`, the pattern this copies for an
  untestable OS singleton), ADR 0182 (backup exclusion, which this one does *not* make a choice),
  ADR 0162 (the Settings hub this deliberately does **not** join), ADR 0165 (the manual quotes the
  app)
- **Schema:** none. No `@Model`, no field, no migration. Diagnostics are a small JSON file in
  Application Support and never enter SwiftData.

## Context

Red Moon is in closed beta and has no crash visibility of any kind. No MetricKit, no exception
handler, no third-party reporter. A blind-spot review on 2026-08-22 confirmed it: if the app dies on
a tester's phone, the only route that information can take back to us is the tester noticing,
remembering, and typing it into the contact form.

Aptabase will never fill this gap and is not supposed to. It is opt-in analytics over a **closed
vocabulary** of event cases (ADR 0120), it is structurally forbidden from carrying a free `String`
(`.swiftlint.yml` `custom_rules`), and ADR 0147 says in as many words that none of it is *"licence to
widen what is collected."*

The gap is not hypothetical. This codebase has already shipped a device-only `SIGTRAP` — the
`@Sendable` AVAudio tap — that every simulator run was blind to. That is exactly the class of bug a
beta exists to find and exactly the class this app currently cannot hear about.

The obvious answer, attaching logs to a support message, was already considered and **rejected**.
ADR 0161 D3:

> the moment what is attached stops being something a player can read in full on one line, "we send
> this and nothing else" stops being a sentence we can honestly write on the screen.

That rejection is correct and stands. This ADR is the version that does not violate it.

## Decision

**MetricKit reports crashes and freezes into a five-event local record; the player can read it on
`Help & About ▸ Diagnostics`; and one bounded line from it travels with a support message only if
they turn it on.**

### D1 — a bounded line, not a log

The line looks like this, and this is the whole of it:

```
3 crashes since 12 Aug · EXC_BAD_ACCESS · iOS 18.2
```

Count, oldest date, what the OS called the most recent one, and the OS version. That is readable in
full on one line, which is the test ADR 0161 D3 actually sets — the rejected alternative was
**unbounded** logs, not the idea of saying anything at all. `SupportDiagnostics` gains a fourth,
optional field and `summary` appends it, so the string in the sheet and the string in the payload
are the same string reached through the same property. That invariant is 0161's and it survives
intact.

The bound lives in `DiagnosticSummary`, not in whatever MetricKit happened to deliver: five events,
nothing older than about three months, and a single line however bad a week the app has had.
`testTheLineStaysOneShortLineEvenAfterManyCrashes` feeds it forty crashes and pins the output.

### D2 — off by default, and it is the only preference here that is off on principle

`AppSettings.attachDiagnostics` defaults to **false**. A summary that attached itself would be true
to the letter of 0161 D3 — it is still readable on screen — and false to its point. Nothing leaves
the device unless the player turns it on *and* sends a support message.

### D3 — crashes and freezes only

`MXDiagnosticPayload` also carries CPU exceptions, disk-write exceptions and launch diagnostics. All
three are dropped rather than mapped. They are performance advisories about a build, none of them is
something a player noticed, and each one that appeared would push a real crash off a five-row screen.
Dropping them is the retention budget being spent on what it was raised for.

Freezes are called **freezes**, not hangs. Nobody outside the room the API was named in calls it a
hang.

### D4 — `Help & About`, not a tenth Settings destination

ADR 0162 D2 groups the hub by *"what am I trying to change?"* Diagnostics changes nothing, and its
only purpose is to feed a support message, so it sits beside *Contact Support* — one level in, on a
screen a player opens once, after something has already gone wrong.

This is also why the Settings hub still has **ten** rows and `check-manual.py`'s C1 needed no change:
ADR 0181 took it from nine to ten and this ADR takes it no further.

### D5 — the pure half holds every decision

`DiagnosticSummary` is Foundation-only and unit-tested: retention, the noun, the date format, the
Mach-exception and signal names, the OS-version shortening. `DiagnosticsRecorder` talks to MetricKit
and holds no judgement at all.

This is `TrialReminderPlan` / `TrialReminder` again (ADR 0144 D6), for the same reason: an OS
singleton cannot be driven from a test, so nothing worth asserting may live behind it. The recorder
copies that ADR's hard-won detail too — **`usesSystemMetrics` is a `Bool` flag, never a stored
`MXMetricManager`**, because holding a non-`Sendable` OS singleton on a `@MainActor` type compiled
clean locally and failed CI's stricter Xcode 16 with *"sending risks causing data races"*.

`DiagnosticEvent.events(from:)` — the one function that imports MetricKit and touches a payload —
lives in the recorder's file rather than the pure one, the same separation ADR 0181 D2 made between
`ArchiveBuilder` and `ArchiveSource`.

### D6 — the subscriber is owned at the app root, and this is not a style choice

`MXMetricManager` holds its subscribers **weakly**. A recorder created inside the Diagnostics screen
would be dropped by the OS the moment that screen went away, and the failure has no symptom: the
screen stays empty, which is also what a healthy app looks like. So `DiagnosticsRecorder` is a third
`@State` at `PocketApp` beside `store` and `trialReminder`, injected through the environment.

Both readers take it as an **optional** environment value. The non-optional form traps wherever the
app root is absent, which is every preview and the settings UI tests.

### D7 — the record is held out of backup, unconditionally

ADR 0182 made the songs exclusion a *choice* because a missing song copy is something a player would
notice on a restored phone. Nobody misses a crash report. It describes a build that is about to be
replaced, and restoring it would attach the old phone's crashes to the new one's support message. So
this exclusion is not a setting and does not appear on the Storage screen's toggle.

### D8 — nothing routes through analytics, and consent is untouched

No `AnalyticsEvent` case is added. ADR 0147 is explicit that none of this is licence to widen what is
collected, and it is structurally blocked anyway — `.swiftlint.yml` forbids a free `String` on an
event case. MetricKit delivery is an OS→app **local** callback; `Analytics.send` remains the only
consent gate and `AptabaseSink` the only vendor path. The `didReceive(_ payloads: [MXMetricPayload])`
callback is implemented and deliberately **empty**: the daily metrics payload is battery, launch
times and network transfer, which we neither asked for nor have any consented route to send.

## Alternatives considered

**A third-party crash reporter (Sentry, Crashlytics, Bugsnag).** Better symbolication, live delivery,
a dashboard. Rejected: ADR 0120 keeps the app to **one** pinned third-party dependency, every one of
these ships an SDK that runs before consent, and Crashlytics in particular is a Google SDK with its
own privacy-manifest and data-sharing story. The gain is not worth what it costs the privacy claim.

**A custom `NSSetUncaughtExceptionHandler` / signal handler.** Catches more than MetricKit and
catches it immediately. Rejected: writing from a signal handler is a minefield, it cannot see the
crashes that matter most here (a `SIGTRAP` from a Swift runtime trap kills the process in ways a
handler often cannot survive), and it would be new unaudited code running at the app's most fragile
moment. MetricKit is the OS doing this correctly for free.

**Send reports automatically.** Rejected outright. It reverses D2 and there is no consented route
for it (D8).

**Attach the payload's JSON.** Rejected — that is the unbounded log ADR 0161 D3 turned down, wearing
a different name.

**A Diagnostics row on the Settings hub.** Rejected per D4; a screen this situational does not earn a
permanent top-level row, and the hub had just grown by one.

## Consequences

**MetricKit delivers roughly once a day, not on demand.** The screen will be empty for a day after a
crash, and an empty screen on the day you go looking is the normal case rather than a fault. The
section footer says so, because without it the first thing this feature does is look broken.

**Nothing here is proven by a green simulator run.** No payload can be constructed in a test and the
simulator delivers none, so `DiagnosticEvent.events(from:)` — the mapping from `MXCrashDiagnostic` to
our values — is the one part with no test behind it. Everything downstream of it is tested; the
reduction itself is verified on device.

**Four privacy artefacts move together** (ADR 0120's rule, ADR 0161 D7's timing): the manifest's
`OtherDiagnosticData` comment is widened here, and the App Store nutrition label,
`docs/app-store-listing-copy.md`, `docs/privacy-policy.md` and the **live policy page in the `uk-site`
repo** must say the same thing before this ships. The live page auto-deploys on every push and is the
one that a player can read today.

**`SupportRequestTests.testPayloadCarriesNothingTheSheetDoesNotShow` was changed on purpose.** Its
own failure message set three conditions for adding a payload key — the sheet shows it, 0161 D3 is
honoured, the manifest is updated — and all three are met above. `testPayloadNeverCarriesAnIdentifier`
is untouched and still passes.

**A support message can now have two lines of disclosure instead of one.** That is a real cost to the
sheet's simplicity, paid only by players who opted in.
