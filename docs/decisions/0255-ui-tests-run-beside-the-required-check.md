# ADR 0255 — The UI tests run beside the required check, not inside it

- **Status:** Accepted — decided with Tomisin, 2026-10-17, as step 0 of the release plan (pricing,
  the Practice hub, the detail sheets). Built on `pocket-366-ci-split-ui-tests`.
- **Date:** 2026-10-17
- **Amends:** ADR 0053 — CI no longer runs `PocketAll`. It runs `PocketLogic` in the required job
  and a new plan, `PocketUI`, in a second job (D1, D2). The plans, the boundary between them and the
  rejection of parallel testing stand.
- **Relates to:** 0133 (the required check always reports, and a docs-only change skips the work, not
  the check; both still hold for the required job) · 0146 (the retry allowance and the report that
  names every retry, now in both jobs) · 0165 D8 (the manual check stays inside the required job)
- **Schema:** none.

## Context

One CI job, `Lint · Build · Test`, ran everything: the manual check, lint, the build, about 3,900
unit tests and 51 UI tests. It is the one required check on `main`. On main's last run (`dca4be7`,
2026-10-16) it took 28 minutes: about 6 to build and run the unit tests, and 22 for the UI tests. Its
timeout had been raised twice, from 30 to 45 and then to 60, because green runs kept growing into it.

Every PR waited those 28 minutes to merge, and one UI test that flaked on the runner held the PR
until it was re-run. The release plan has four feature branches to land in series, so the wait is
paid four times over.

The simulator was "the first iPhone `simctl` lists". On the current image that is an iPhone 16 Pro on
iOS 18.5. Nothing pinned it, so an image update could have moved CI to another OS with no change in
this repo. iOS 18 matters: two bugs that passed on iOS 26 and on the phone only showed up on it (a
`.sheet` on a List row losing its write, a toolbar Menu that was never hittable).

## Decision

**D1 — Two jobs, side by side.** `Lint · Build · Test` keeps its name, so branch protection still
matches it. It runs the manual check, lint, the build and `PocketLogic`. A second job, `UI tests`,
runs `PocketUI` on its own macOS runner at the same time. Both need only `scope`. The required job
keeps ADR 0133's shape: it always runs and reports, and only its steps skip on a docs-only change. The
UI job skips as a whole on a docs-only change, with a job-level `if:`. That is safe only because
nothing requires it.

**D2 — `PocketUI` is a plan, not a flag.** It holds the `PocketUITests` target alone. A plan is used
rather than `-only-testing:PocketUITests` on `PocketAll` for the reason 0053 gives: a flag list
drifts, and `-only-testing:` can run nothing and exit 0. `PocketAll` stays as the local "run
everything" plan, and the pre-push hook's `full` tier still uses it. `check-manual.py` C14 now checks
every plan except `PocketShoot`, not just `PocketAll`, so the shoot cannot leak into `PocketUI` or
into a plan added later.

**D3 — `UI tests` is not a required check.** A UI test that flakes on the runner no longer holds a
PR. The guard moves from the merge to the release:

> **No release build until main's UI job is green.**

`scripts/main-ui-green.sh` checks it. It walks back from main's head to the newest commit whose UI job
actually ran (a docs-only commit skips it) and exits 0 only if that run passed. A cancelled, failed,
timed-out or still-running result is not green. `/ready-to-ship` runs it, so the rule is a check, not
a sentence to remember. The UI job runs on pushes to `main` for this reason.

A PR may merge once the required job is green. If its UI job has already gone red, read why before
merging. A UI failure the change caused is a release blocker brought onto `main`.

**D4 — The simulator is pinned by name and iOS version:** iPhone 16 Pro, iOS 18.5, set once as
`SIM_NAME` / `SIM_OS` at the top of `ci.yml`. `scripts/ci-simulator.sh` finds it, boots it and waits
until it has settled (0146), for both jobs. If the image no longer has it, the step fails and lists
what the runner does have. A silent fallback is how the OS would drift.

**D5 — Each job proves its tests ran.** `scripts/assert-tests-ran.sh` fails the step when the raw log
has no passing test case. With two plans in two jobs, an edit to either `.xctestplan` could empty one,
and an empty plan prints `** TEST SUCCEEDED **`.

## Alternatives

- **Both jobs required.** This keeps a flaky UI test blocking the merge, and the merge still waits
  for the slower job. It buys nothing over one job but a second runner.
- **UI tests on `main` only.** This drops the signal from PRs, so a break is found after it has
  merged. The UI job runs on PRs anyway; it just doesn't block them.
- **Build once, test twice** (`build-for-testing`, upload the products, `test-without-building` in
  both jobs). The two jobs then wait on one build, and the upload and download cost minutes. The
  build is about 5 of the required job's minutes, so two runners each building in parallel finish
  sooner. Revisit if the build grows.
- **Parallel testing in the UI job.** 0053 rejected it with 2 UI tests: clone start-up cost more
  than it saved, and the runner failed to launch on a clone. There are 51 now, so it may be worth
  measuring again, but not in this change. Mixing two changes would leave neither one's effect
  readable. It stays rejected until it is measured.

## Consequences

- A PR can merge in roughly the time it takes to build and run the unit tests, under 10 minutes
  from about 30, while the UI tests keep reporting beside it.
- A UI break can now reach `main`. The release rule (D3) is what stops it from reaching players. The
  release step (`pocket-370`) runs `/ready-to-ship`, which runs the check.
- Each run uses two macOS runners. The repository is public, so this costs queue time, not money.
- Two artifacts per run: `TestResults` (unit) and `UITestResults` (UI). Each holds its result bundle
  and its raw `xcodebuild` log.
- The required job's timeout drops from 60 to 30 minutes. The UI job keeps 60.
