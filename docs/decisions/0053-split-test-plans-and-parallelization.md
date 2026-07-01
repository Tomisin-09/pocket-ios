# 0053 — Split test plans: fast logic-only local, full CI

- **Status:** Accepted
- **Date:** 2026-07-01

## Context

The suite is ~498 unit tests (`PocketTests`) plus 2 UI tests (`PocketUITests`),
all hosted in the app and run through the simulator. The pre-push checklist
(AGENTS.md step 3) ran the whole thing — unit + UI + code coverage — on every push,
which is the slow part of the inner loop. Two cheap, config-only levers were agreed
before touching any test code: (1) split into a fast local plan and a full CI plan,
and (2) turn on parallel execution. Both were tried; the second was **measured and
rejected** (see below). Extracting the pure logic into an SPM package (macOS tests,
no simulator) remains the fallback for a real speedup, but it's a refactor and is
deferred.

## Decision

- **Two `.xctestplan`s wired through `project.yml`** (XcodeGen `schemes.Pocket.test.testPlans`,
  so the scheme stays generated, not hand-edited):
  - **`PocketLogic.xctestplan`** — `PocketTests` only, `codeCoverage: false`. Marked
    `defaultPlan`, so a bare `xcodebuild test -scheme Pocket` (the pre-push command)
    runs it. Fast inner loop.
  - **`PocketAll.xctestplan`** — `PocketTests` + `PocketUITests`, `codeCoverage: true`.
    CI selects it explicitly with `-testPlan PocketAll`, so both suites and coverage
    still gate merges.
- **The default/fast plan drops the 2 UI tests and coverage gathering** — UI tests
  each cold-launch the app (~13s + ~12s) and coverage instrumentation adds ~40s;
  neither earns its cost on every local push, and CI still enforces both.
- **No parallel test execution.** It was benchmarked and did not pay off (data below),
  so neither plan marks targets `parallelizable` and CI does not pass
  `-parallel-testing-enabled`.

The logic-vs-integration line is drawn at the **target** boundary (unit vs UI), not
by hand-curating individual `PocketTests` classes: the ~16 unit-test files that touch
SwiftData use in-memory containers and are fast, and curating classes would be a
fragile list every new test file has to be added to.

## Why not parallel execution

Benchmarked test-phase-only (build excluded, warm) on an iPhone 17 Pro simulator:

| Config | Time | Result |
|---|---|---|
| Full suite (unit + UI + coverage), serial — the old default | 123s | ✓ |
| Logic-only, **serial** | **59s** | ✓ |
| Logic-only, parallel (cloned sims) | 66s | ✓ |
| Full suite, parallel (`-parallel-testing-enabled YES`) | 314s | ✗ UI runner failed to launch |

Two findings: (1) the 498 unit tests are individually tiny (mostly <0.01s), so
simulator-clone spawn overhead **exceeds** any parallel gain — serial was actually
faster. (2) Forcing parallelism on the UI target makes the XCUITest runner fail to
launch on a clone (`FBSOpenApplicationServiceErrorDomain`), turning the full run red
*and* slow. The ~2× win is entirely from the split (dropping UI + coverage locally),
not from parallelism — so parallelism was dropped.

## Consequences

- Local pre-push: ~123s → ~59s, no test code changed.
- CI is unchanged in what it enforces (full suite + coverage), just selected via a
  named plan.
- New unit tests are picked up automatically (target-level membership). A new *UI*
  test only runs in CI unless a developer selects `PocketAll` locally.
- If the local ~59s still isn't fast enough, the next step is the deferred SPM logic
  package (macOS `swift test`, no simulator) — the only lever left, since parallelism
  is exhausted.
