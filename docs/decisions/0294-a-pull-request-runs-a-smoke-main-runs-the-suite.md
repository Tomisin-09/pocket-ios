# ADR 0294 — A pull request runs a UI smoke; `main` runs the whole UI suite, once

- **Status:** Accepted — decided with Tomisin, 2026-11-11. Built on `pocket-422-ci-smoke-on-prs`.
- **Date:** 2026-11-11
- **Amends:** ADR 0255 — its two jobs no longer both run on every event. The required job runs on
  pull requests and not on pushes to `main` (D1). The UI job runs a smoke plan on pull requests and
  the whole suite on `main` only (D2, D3), which is the "UI tests on `main` only" alternative it
  rejected, taken with a smoke run in the gap. The required check, its name, the release rule, the
  pinned simulator and the tests-ran assertion stand. · ADR 0053 — a fifth plan, `PocketSmoke` (D2).
  The other four and the target boundary stand.
- **Relates to:** 0133 (the required check always reports on a pull request; D1 skips it only where
  nothing requires it) · 0146 (the retry allowance, unchanged) · 0191 (the last time CI's minutes
  were counted; its refusal to drop UI tests from pull requests was about the required check, which
  0255 has since taken them out of)
- **Schema:** none.

## Context

Measured on main's run of 2026-11-11 (`bc34dc6`) and on the 200 runs before it (2026-09-25 on):

| Piece | Time |
|---|---|
| A full run, wall clock | about 50 minutes |
| `Lint · Build · Test` | about 13 minutes: 9 to build, 56–70 seconds for 4,432 unit tests |
| `UI tests` | about 50 minutes: 10 to build, 39 for 64 tests |

When 0255 split the jobs the UI suite was 51 tests and 22 minutes. It is 64 and 39 now.

Every merge paid for all of it twice. Branch protection on `main` is strict: a pull request must be
up to date before it merges. So the commit a squash merge puts on `main` has the same tree the
pull request's last run tested, and the push run repeated that run exactly. Of 163 full runs in
seven weeks, 72 were pushes to `main`.

The unit tests are not where the time is. All 4,432 run in about a minute, so deleting any of them
saves seconds.

## Decision

**D1 — The required job does not run on a push to `main`.** `Lint · Build · Test` has a job-level
`if: github.event_name != 'push'`. On a pull request it runs and reports exactly as before, which
is the only place the check is required, so 0133's rule holds: this is not a paths filter, and it
can never leave a pull request waiting on a check that does not report.

**D2 — A pull request runs `UI smoke`.** A fifth plan, `PocketSmoke`, is the `PocketUITests` target
narrowed by `selectedTests` to 13 tests: the launch tests, a practice run, the starter track, a
shared audio file arriving, the Toolkit and Settings hubs, the Home tool tile and the plan wall.
They took 3 minutes 40 seconds of the 39 on the measured run. It is a plan, not `-only-testing:`
flags, for 0053's reason.

The two Export tests (a song received, a song's audio exported) were in the first cut and came out
after its first run on CI (PR #414, 2026-11-12). That runner was slow throughout: the unit job's
build and tests took 18 minutes against 10 on main's last run, and every smoke test took 1.3 to 8.7
times as long as on main. The Export tests were worst, because classes run in alphabetical order and
they ran first, on the coldest simulator: the suite took 11 of the 20 test minutes, and
`testASongsAudioExportsFromSongDetails` missed its 10-second wait for the Start here card, spent 5½
minutes failing and passed on its retry. In the full suite they run fifth and have not failed that
way. A file arriving is still covered by `SharedAudioUITests`, and both Export tests still run on
`main`.

**D3 — `main` runs `UI tests`, the whole suite, once per merge.** Same job, same plan (`PocketUI`),
same check name, so `scripts/main-ui-green.sh` and the release rule are untouched: **no release
build until main's UI job is green.** The job takes its name from the event, `UI smoke` on a pull
request and `UI tests` otherwise, so a smoke run can never be read as the suite.

**D4 — The workflow can be dispatched by hand.** `workflow_dispatch` on a branch runs the required
job and the whole UI suite. This is how a change that reworks a screen gets the full suite before
it merges.

## Alternatives

- **No UI tests on pull requests at all.** Simpler, and a UI break is found after merge either way.
  But a change that stops the app launching would then reach `main` unseen, and the smoke costs
  under four minutes of tests on a runner nobody pays for.
- **Keep the whole suite on pull requests and drop the push run.** The release rule would have to
  follow each commit on `main` back to its pull request's run. It also keeps the 50-minute run on
  every push to a branch.
- **Keep running the required job on `main`.** It costs no waiting, since the UI job is the longer
  one. It also tests nothing: the tree is the one the pull request tested.
- **Delete unit tests.** They take about a minute in total.
- **Build once, and shard the suite across jobs.** 0255 and 0191 both put this off until the build
  was worth it. At 9–10 minutes built twice, it now is. It is the next change, kept out of this one
  so each one's effect can be read.

## Consequences

- A pull request's UI job runs under 4 minutes of tests instead of 39. Its simulator boot and build,
  about 12 minutes, are unchanged, so on a runner as fast as main's of 2026-11-11 the job should take
  about 17 minutes instead of 50. A slow runner stretches all of it: the first run took 38, with the
  Export tests still in it. Those fixed 12 minutes are now most of the job, which is why building
  once is the next change.
- Each merge runs the whole UI suite once instead of twice, and the unit tests once instead of twice.
- **A UI break outside the smoke is found on `main`, after the merge.** 0255 already allowed a merge
  before the UI job finished; this makes that the normal case. The release rule is what stops the
  break reaching players, and D4 is there for a change that wants the suite first.
- A merge that bypasses branch protection reaches `main` with no unit-test run on it. The UI job
  still builds the app there.
- `PocketSmoke` is a list of class and test names. A renamed class drops out of it silently and the
  smoke gets smaller. `assert-tests-ran.sh` catches the plan running nothing, not the plan running
  fewer.
