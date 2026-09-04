# ADR 0191 — what CI's twenty minutes is actually spent on

- **Status:** Proposed — measuring (branch `pocket-297-ci-time`)
- **Date:** 2026-09-04
- **Relates to:** ADR 0146 (test-suite reliability — the retry allowance and the simulator pre-boot
  this builds on) · ADR 0133 (never `paths-ignore` on `ci.yml`; the `scope` job is the sanctioned way
  to skip work) · ADR 0165 D8 (`check-manual.py` runs regardless of scope)

## Context

The run that merged ADR 0190 took **20m 2s**. The observation that prompted this was that jobs seem
to be averaging ~15 minutes and trending up "due to the test build-up", and that the trend continues.
The trend is real. The attribution is not, and the difference decides what is worth doing.

### Where the time goes

Job `lint-build-test`, from the Actions API:

| Step | Time |
|---|---|
| **Build & test** | **1149s** |
| SwiftLint | 7s |
| `brew install` tools | 6s |
| checkout · manual check · xcodegen | ~5s |
| everything else | ~30s |

**96% of the job is one step.** Nothing outside it is worth optimising — the lint that covers 803
files costs seven seconds.

Inside that step, from the local run of the same commit:

| | Count | Wall clock |
|---|---|---|
| Unit tests (`PocketTests`) | **2741** | **23s** |
| UI tests (`PocketUITests`) | 12 | 333s |

### The finding: the unit suite is not the problem and cannot become one

Two thousand seven hundred and forty-one unit tests cost **twenty-three seconds**. A thousand more
would cost single-digit seconds. The project's habit of unit-testing pure logic (AGENTS.md requires
it for tempo math, planner weighting, identity) is therefore free at CI scale, and no reasonable
amount of it will change this job's runtime.

The growth is in two other places:

1. **Compilation.** CI built the app and both test targets from cold on every single run.
   `grep -c actions/cache .github/workflows/ci.yml` returned **0**. This scales with the size of the
   source tree, which only goes up.
2. **UI tests, at ~28s each.** `PocketLaunchUITests.testAppLaunches` does nothing but launch the app
   and costs **11.1s**. That is the floor every UI test pays. Twelve tests means roughly 130s of the
   333s is app launches, before a single assertion runs.

This reframes the lever. The cost is not *how many tests* but *how many app launches* and *how much
gets recompiled*.

## Decision

Three changes, each committed and measured separately so the ones that do not pay can be reverted on
evidence rather than kept on faith.

**How each is isolated.** A cache cannot be measured by the run that fills it, and the obvious second
run would also carry the next change — confounding the two. So the cache is measured by **re-running
the identical commit** (`gh run rerun`) once the cache exists: same tree, same everything, the only
difference being a populated cache. D2 and D3 then each get their own push, with the cache warm on
both sides of the comparison.

### D1 — cache build products, keyed to miss usefully

`-derivedDataPath DerivedData` plus `actions/cache`. The exact key is the whole source tree, so any
edit misses it; the **`restore-keys` prefixes** are the working part, handing Xcode the previous
build to compile incrementally against. A total miss costs only the restore attempt, so the downside
is bounded.

The Xcode version is in the key deliberately. Build products are not portable across toolchains, and
a stale restore is the one failure mode here that would present as a **mysterious compile error
rather than a slow run** — which is the kind of failure that costs far more than the cache saves.

Cross-runner incremental Swift builds are genuinely finicky (module fingerprints, absolute paths).
This is adopted on measurement, not on principle: two runs are needed, one to populate and one to
hit.

### D2 — code coverage is gathered and read by nobody

`PocketAll.xctestplan` sets `"codeCoverage": true`. Nothing in the repository consumes the result —
no report, no badge, no gate, no threshold. The `.xcresult` is uploaded as an artifact, but for
diagnosing failures, which needs no instrumentation.

**The precedent is already in the repo, with the reasoning written out.** `scripts/shoot-manual.sh`
passes `-enableCodeCoverage NO` and says why: *"the plan turns coverage on, which instruments the app
under test and buys a shoot nothing. It is timing cost on exactly the code path the captures race
against."* The shoot reached this conclusion for its own reasons; it applies to every run of the
plan.

Turned off in the **test plan** rather than by a flag in `ci.yml`, so local runs get it too and there
is one place to turn it back on. That trap is worth naming, because `shoot-manual.sh` already hit it:
instrumentation is decided **when the binary is built**, so a flag passed only to
`test-without-building` skips gathering the data while still paying for it.

### D3 — run UI tests in parallel on cloned simulators

`-parallel-testing-enabled YES -maximum-parallel-testing-workers 2`. Each worker gets its own cloned
simulator, which also **helps** the hazard this project has already been bitten by: a simulator keeps
its `UserDefaults` between runs, so tests that share one inherit each other's state. Clones do not.

Two workers, not more. The runner has limited cores, and contention is how a parallel suite converts
a time saving into a flake — which ADR 0146 spent two passes buying back.

## Rejected

- **Sharding tests across parallel *jobs*.** It sounds right and is the eventual answer, but each job
  rebuilds unless `build-for-testing` → artifact → `test-without-building` is wired up, and the
  upload/download of build products can eat the gain. Worth doing after D1 shows what a warm build
  actually costs; doing it first would be optimising a number nobody has measured.
- **A larger runner** (`macos-15-xlarge`). Billed at a multiple of standard minutes. Buying speed is
  available at any time and teaches nothing about where the time went.
- **Skipping UI tests on pull requests, running them only on `main`.** This is the largest single
  saving available and it is refused: `lint-build-test` is the **required** check, and a required
  check that does not run the tests that catch UI regressions is a check that reports a green it has
  not earned. ADR 0133 already establishes that this repo does not weaken the required check for
  convenience.
- **Dropping `-retry-tests-on-failure -test-iterations 2`.** It costs nothing on a green run — it
  only re-runs what failed. Removing it is a reliability decision (ADR 0146 wants a stretch of
  retry-free runs first), not a time one.

## Consequences

To be completed when the three runs land.
