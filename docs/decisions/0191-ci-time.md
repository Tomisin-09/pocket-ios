# ADR 0191 — what CI's twenty minutes is actually spent on

- **Status:** Accepted — **D1 and D3 measured and REJECTED**; only D2 ships (branch `pocket-297-ci-time`)
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

### D1 — cache build products — **TRIED, MEASURED, REVERTED**

`-derivedDataPath DerivedData` plus `actions/cache`. The exact key is the whole source tree, so any
edit misses it; the **`restore-keys` prefixes** are the working part, handing Xcode the previous
build to compile incrementally against. A total miss costs only the restore attempt, so the downside
is bounded.

The Xcode version is in the key deliberately. Build products are not portable across toolchains, and
a stale restore is the one failure mode here that would present as a **mysterious compile error
rather than a slow run** — which is the kind of failure that costs far more than the cache saves.

Cross-runner incremental Swift builds are genuinely finicky (module fingerprints, absolute paths).
This was adopted on measurement, not on principle — and **the measurement rejected it.** See *The
cache restored perfectly and saved nothing*, below. The description above is kept as written so the
reasoning that looked sound can be compared against what happened.

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

### D3 — run UI tests in parallel on cloned simulators — **TRIED, MEASURED, REVERTED**

`-parallel-testing-enabled YES -maximum-parallel-testing-workers 2`. Each worker gets its own cloned
simulator, which also **helps** the hazard this project has already been bitten by: a simulator keeps
its `UserDefaults` between runs, so tests that share one inherit each other's state. Clones do not.

Two workers, not more. The runner has limited cores, and contention is how a parallel suite converts
a time saving into a flake — which ADR 0146 spent two passes buying back.

**Reverted.** It failed on time and, far more seriously, it blinded ADR 0146's flake guard. See *The
parallel run went green and could not prove it*, below. The reasoning above is kept as written,
because it was not obviously wrong — it was wrong for a reason nobody would have predicted from the
flag's description.

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

## The cache restored perfectly and saved nothing

**D1 is reverted.** It was measured exactly as designed — the same commit re-run with the cache cold
on one side and warm on the other — and the answer was unambiguous:

| Run | Build & test | unit | UI | **rest ≈ compile** |
|---|---|---|---|---|
| baseline #290 (no cache) | 1149s | 23s | 333s | 793s |
| run 1 — D1, **cold** cache | 725s | 30s | 282s | **413s** |
| run 2 — D1, **warm** cache | 825s | 29s | 382s | **414s** |

The cache worked *mechanically* and completely: `Cache restored from key: dd-macOS-Xcode16.4-…`,
`Cache hit occurred on the primary key`. And the compile portion moved from **413s to 414s**. Xcode
rebuilt the entire tree anyway.

**Why, and it is not subtle in hindsight:** a fresh `git checkout` gives every source file a new
mtime, and Xcode's incremental build keys on mtimes. Every file looks modified, so every file is
recompiled, and the restored `DerivedData` is dead weight — 8s to restore and 9s to save, for
nothing. Restoring build products cannot help a build whose invalidation signal was destroyed by the
checkout that preceded it.

This is worth keeping as a finding rather than a deleted branch, because *"add a DerivedData cache"*
is the first suggestion anyone makes about slow Xcode CI, it is what the internet recommends, and it
does not work here. Anyone reaching for it again should have to argue past this table.

**What it did establish**, and this is the number the next lever needs: a cold compile on this
project is **~413s**, consistently, across two runs on different boxes.

## The parallel run went green and could not prove it

**D3 is reverted, for two reasons, and the second is the one that matters.**

**It was slower.** The test phase roughly doubled:

| Run | build | tests |
|---|---|---|
| run 1 (serial) | 413s | 312s |
| run 2 (serial) | 414s | 411s |
| **run 3 (parallel, 2 workers)** | 549s | **792s** |

Two simulators contending for a limited-core runner make every UI test slower, and each clone pays
its own boot — the cost this ADR predicted it was adding back, at a size it did not predict. The
regression is far outside the ±100s noise band, which is what made a one-sided test worth running.

**And it silently disabled the flake detector.** `scripts/report-test-retries.sh` reported:

> `##[warning]No 'Test Case' lines found in 'xcodebuild-raw.log' — the run probably died before the
> tests started. This is NOT a clean suite; check the build step.`

Parallel testing changes `xcodebuild`'s output format. The per-test `Test Case '-[…]' passed` lines
the script parses are not emitted the same way, so the guard that exists precisely because **a green
run with retries is not a clean run** (ADR 0146) could see nothing at all — while the job reported
success.

That is the exact failure this project has a script to prevent, arriving through a flag that has
nothing to do with retries. **A check that silently stops checking is worse than a slow one**, and it
would have shipped as a speed improvement. If parallel testing is ever revisited, the retry reporter
has to be taught the parallel output format *first*, as a precondition rather than a follow-up.

## The measurement did not survive contact with the runners

**A single run cannot measure a two-minute change on `macos-15`, and the first run proved it.**

Run 1 carried D1 and had a **provably cold** cache — the log says `Cache not found for input keys`.
It should therefore have matched the 1149s baseline. It came in at **725s**, a 36% drop the cache
cannot explain, on nearly the same tree:

| | Baseline (#290) | Run 1 (cold cache) |
|---|---|---|
| Unit tests | 23s | 30s |
| UI tests | 333s | 282s |
| Everything else (mostly compile) | **~750s** | **~380s** |

Two cold builds, and the compile half differs by **2×**. GitHub's `macos-15` pool spans hardware
generations; which box a run draws is worth more than any change in this ADR.

The re-run then produced the sharper version of the same point: **identical code, identical commit,
and UI tests took 282s on one run and 382s on the other** — a 35% swing with nothing changed but the
machine and the day. That ~100s of noise is larger than the entire expected effect of D2 and D3
combined.

The consequence is a change of method, recorded because the original plan was wrong in a way that
would have produced confident nonsense: **one run per lever was under-powered, and would have
reported noise as a result.** D2 and D3 are each plausibly 60–120s — comfortably inside that band.

So the levers are held to different standards, deliberately:

- **D1 was taken on measurement** — the only one large enough to clear the noise floor, and the only
  one measurable *cleanly*. It failed that test and was reverted. The method worked: it cost two runs
  and it stopped a plausible, well-reasoned, useless change from landing.
- **D2 and D3 were taken on reasoning plus a green run, and were NOT individually measured.** Saying
  so is the point: claiming a measured saving that cannot be distinguished from runner variance would
  be worse than claiming nothing. What a green run *does* give is a **one-sided test** — it cannot
  prove a small win, but it would expose a large regression.

  **That one-sided test earned its keep immediately.** It caught D3's doubled test phase, and the
  green-but-unverifiable run underneath it. Two of the three changes in this ADR were killed by
  their own measurements; the discipline is the deliverable here, more than the one surviving line
  of JSON.

D2 needs the least defending of the three anyway, and not because of timing: **`PocketAll` was the
only plan with coverage on.** `PocketLogic` and `PocketShoot` are both already `false`. The question
had been settled twice and the one plan CI actually runs was never revisited, so this is a
consistency fix that happens to save time.

## Consequences

- **CI has no build cache, deliberately and on evidence.** Do not add one without defeating the mtime
  problem first; the table above is the argument to beat.
- **Coverage is off everywhere now.** If a coverage number is ever wanted, the switch is
  `PocketAll.xctestplan`, and it must be turned on *there* rather than by a flag on a test step —
  instrumentation is decided when the binary is built (`shoot-manual.sh` learned this the hard way).
- **UI tests still run serially, on one pre-booted simulator.** Parallelism was tried and reverted;
  do not reach for it again without first teaching `report-test-retries.sh` the parallel output
  format, or the flake guard goes blind exactly when the suite gets more concurrent.
- **`report-test-retries.sh` is load-bearing and fragile.** It parses `Test Case` lines out of the
  raw log, so anything that changes `xcodebuild`'s output shape disarms it. It failed loudly here,
  which is the only reason this was caught — that warning is worth keeping loud.
- **The next lever is sharding, and it now has a number to beat: ~413s of compile.** Sharding pays
  only if the build is done *once* and the products are handed to test jobs — `build-for-testing` →
  artifact → `test-without-building`. Note what D1 proved about that plan, because it cuts both ways:
  transferring build products between runners is exactly what the cache did successfully, so the
  transfer is not the risk; the risk is that a `test-without-building` job must not re-derive
  anything, or it inherits the same mtime problem.
- **Do not trust a single CI run to measure anything under ~100s.** UI-test time alone swings 35% on
  identical code. Anything smaller needs medians over several runs, or an argument instead.
- **What actually shipped is one line of JSON.** `PocketAll.xctestplan` stops gathering coverage
  nobody reads. Whether that is worth measurable time is unknown and unclaimed.
- **Nothing was traded away from the required check.** `lint-build-test` still lints, still builds
  Swift-6-strict, and still runs the whole `PocketAll` plan including every UI test.
