# ADR 0146 — A test suite you can believe

- **Status:** Accepted — pass 1 built on `pocket-236-ui-test-reliability`; pass 2 built on
  `pocket-237-ui-test-readiness-signal`
- **Date:** 2026-08-06 (`pocket-236-ui-test-reliability`)
- **Builds on:** ADR 0133 (which decides *whether* the `PocketAll` plan runs; this decides whether
  the answer it gives can be trusted).

## Context

The four UI tests in `PocketUITests/` all wait the same way: a hardcoded generous budget on some
element far downstream of the thing they actually depend on. `PracticeRunUITests.swift:48` and
`RowUndoUITests.swift:44` both wait 20 seconds for a *seeded exercise cell*; the comments beside
them say plainly that a tight 5s "flaked on cold CI/sim runs".

The dependency those budgets are really covering is first-launch seeding, and seeding is not at the
app root. It is a `.task` in `HomeView.swift` that yields between exercises → routines → songs, with
**no completion signal of any kind**. So on a cold install every test that needs a seeded row is
waiting on an async chain it cannot observe, and the only lever available is a guess about how slow
the runner is. A guess is what flakes.

This has already cost real time. `main` went red on 2026-07-29 (CI run 30441349304) on the
post-merge build of PR #188 — a PR that touched nothing in the row-actions path. Two other
investigations reached for a stored diagnosis before checking *which* assertion failed, and were
wrong both times: the `RoutinePresets` "run-screen freeze" was actually the 5s wait for a seeded
exercise cell, and the 20s freeze guard it was blamed on had fired 0 times in 12 runs.

A suite that fails for reasons unrelated to the change under test is worse than no suite, because it
teaches you to disbelieve it — and four large pushes (the monetization change, analytics, Help &
FAQs, and this work's own second pass) are queued behind it.

## Decision

### 1. CI boots and settles the simulator before the timed run

`ci.yml` picked a UDID and handed it straight to `xcodebuild test`, so device boot and SpringBoard
settling happened *inside* the window every one of those waits is budgeted against. CI now runs
`simctl boot` followed by `simctl bootstatus -b` first. `boot` is allowed to fail, because an
already-booted device exits non-zero.

This buys headroom. It does not remove the guess — decision 4 does that.

### 2. Failures are retried, and the retry is reported as loudly as a failure

The run adds `-retry-tests-on-failure -test-iterations 3`. Only failures re-run, so a genuine break
still fails all three attempts, while a one-off timing loss on a cold runner no longer reddens
`main`.

**This trades away "every red is real", and that trade is only acceptable with the other half
attached.** `scripts/report-test-retries.sh` parses the raw `xcodebuild` log and emits a GitHub
warning annotation, plus a job-summary block, naming every test that failed at least one attempt.
The standing rule:

> **A green run with retries in it is not a clean run.** A test that needed a retry is racing either
> the app or the runner, and the next person to see it red will have no idea it was already flaking.

The script deliberately **exits 0 and never fails the build** — failing there would re-create the
exact problem retries were added to solve. It reports; a human decides.

It reads the raw log rather than the result bundle on purpose: `xcresulttool`'s JSON schema has
changed shape more than once, and CI's Xcode 16 / macOS-15 is older than local Xcode 26.5. Matching
`Test Case '…' failed` works across both.

### 3. Animations are off under `-uiTesting`

`UIView.setAnimationsEnabled(false)`, in `AppDelegate.didFinishLaunchingWithOptions` so it lands
before the first view is built. XCUITest blocks on app-idle before every query and every tap, so a
transition's duration is spent by the *test*, not merely by the app, and a loaded runner multiplies
it across every step of every test.

Uses the house `-uiTesting` idiom, which now appears in five places (`Analytics`, `StoreManager`,
`HomeView+ProfileMoment`, `RowDeletionCoordinator`, and here). That duplication is worth collapsing
into one named accessor — noted for pass 2, where the test-side launch seam is already being touched.

### 4. Pass 2 — a readiness signal replaces the guesses

Pass 1 made the runs survivable; this removes the reason they needed to be.

- **Home publishes when seeding is done, not when it renders.** `seedFirstRunContent()` sets
  `seedingComplete`, and `HomeView+Seeding.seedingMarker` puts a 1×1 element carrying
  `UITestHooks.homeSeedingComplete` into the tree. `.accessibilityElement()` is load-bearing — a
  bare `Color` is not an element, so without it the identifier attaches to nothing and every test
  waits out the full budget before blaming the wrong assertion. Only under `-uiTesting`: an
  invisible element is dead weight for a player using VoiceOver.
- **`UITestCase.launchApp()` carries the one generous wait** (`seedingTimeout` 60s) and every test
  now starts there, so a new test cannot forget it. Everything after it asserts against a settled
  app and drops to `uiTimeout` **10s**, down from the 20s guesses. No `setUp` override:
  `XCTestCase.setUp` is nonisolated and an override cannot add isolation its superclass lacks, so
  main-actor work there compiles locally and fails CI's stricter Swift 6.
- **`scrollIntoView(_:in:)` replaces the three blind swipe loops**, stopping when the element is
  hittable *or* its frame stops moving — a fact about the app rather than a guess about how many
  swipes a layout needs.
- **`UITestRuntime.isActive` collapses the five hand-written `CommandLine.arguments.contains`
  copies**, and `UITestHooks` is compiled into both targets (`project.yml`) so the launch argument
  and the identifier are shared constants rather than literals duplicated across a process boundary.

The identifier is found on the **first** poll after launch in every test — the gap the 20s budgets
were covering was real, but it was seeding, and seeding now announces itself.

**Retry flag, revisited as promised:** `-test-iterations` drops 3 → **2**. The cause the larger
budget was covering is gone, so one retry is the remaining allowance — enough for a lost runner,
not enough for a test to flake twice and still come out green. Removing it entirely is the
endpoint, and wants a stretch of retry-free runs behind it: scaffolding that outlives its cause
becomes load-bearing by accident.

### 5. The standing rule this all rests on

> **No product wall-clock may sit inside a test's budget unless the duration is what the test is
> asserting.**

`RowDeletionCoordinator.window` already follows it — 4 seconds in production, 120 under `-uiTesting`
— and the real duration stays covered by `RowDeletionCoordinatorTests`, which runs without the flag
and waits it out.

**Audited every other timed surface against this rule.** The result is that
`RowDeletionCoordinator` is currently the only one inside a test budget, and it is already handled.
These are latent — each becomes a trap the moment a test walks onto its path, which is worth knowing
before Help & FAQs adds a Toolkit test:

| Wall-clock | Where | Reached by a UI test today? |
|---|---|---|
| Undo window, 4s | `RowDeletionCoordinator.swift:57` | **Yes** — already stretched |
| Reference-tone sustain | `TunerView.swift:378` | No — the Toolkit test opens My chords only |
| Rest / auto-advance, 0.8s | `RoutineRunContext.swift:172` | No — the run screen is opened, never started |
| Waveform undo, 4s | `WaveformPracticeModel+Undo.swift:32` | No |
| Long-press and free-drag holds | `WaveformCanvasGestures.swift:182,204` | No |
| Recording countdown, 3s | `RecordControls.swift:200` | No |
| Preview players (tone, loop, strum, command tempo) | five files | No |

## Alternatives rejected

**Just widen the timeouts again.** This is the third time; each widening buys a few months and makes
the eventual failure slower to report. It also treats the symptom — the tests are waiting on the
wrong thing, not waiting too briefly.

**Seed synchronously at app root.** It would give the tests a hard guarantee, but at the cost of the
users': blocking first paint on three model fetch-insert-save cycles is a worse cold-launch for
everybody so that four tests can stop guessing. The yields between seeders exist deliberately.

**Test-only seeding hooks in the app.** A `-seedComplete` notification or a launch argument that
bypasses seeding would work, but the repo has consistently refused test-only code paths in the app
(`RowUndoUITests` writes its own journal note through the real capture path rather than take a
fixture). An accessibility identifier is observable state the app already publishes, not a second
code path.

**Retry without reporting.** The cheapest option and the most dangerous: it converts a flaky suite
into a suite that looks healthy. The annotation is what keeps decision 2 honest.

## Consequences

- A green check no longer means "every test passed first time". The annotation is now part of
  reading a CI result, and a repeat retry on the same test is a bug report.
- Retries cost wall-clock only when something fails, so the common path is unchanged. Pre-booting
  adds a few seconds to every run and takes more than that back out of the test waits.
- Disabling animations means the UI tests no longer exercise transitions at all. Nothing asserted
  them, but a transition that breaks visually will not be caught here — that stays a device check.
- `scripts/report-test-retries.sh` parses log text, so an `xcodebuild` output-format change would
  silently stop it reporting. The result bundle at `TestResults` remains the authority. It does
  **not** treat "no failures" as proof of health: a log containing no `Test Case` lines at all is
  reported as a warning, not a clean suite. That case is not hypothetical — it happened while
  building this ADR (a missing `xcbeautify` killed the pipeline before `xcodebuild` ran) and the
  first cut of the script announced the dead run as "every test passed on its first attempt", which
  is the precise failure mode it exists to prevent.
- Pass 1 alone did **not** fix the root cause, and a flake did survive it — `PracticeRunUITests`
  failed twice on the full plan and passed in isolation, on a 20s wait for a seeded cell. That is
  what pass 2 answers. The rule held under pressure: pass 2's first full-plan run was on a machine
  at load 51 with ~960k pageouts, and the temptation was to read the failure as "10s is too tight"
  and put the number back. Guess-inflation under noise is how the 20s budgets got there in the
  first place; the run was repeated on a healthy machine instead, and passed at 10s.
- `UITestHooks.swift` is compiled into two targets. Anything added to it must stay strings-only —
  an app type in there would mean something different on each side of the process boundary.
