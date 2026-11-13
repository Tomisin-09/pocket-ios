# ADR 0295 — `main` runs the UI suite in three shards, and each shard builds the app itself

- **Status:** Accepted — decided with Tomisin, 2026-11-12. Built on `pocket-423-ci-shard-ui-suite`.
- **Date:** 2026-11-12
- **Amends:** ADR 0294 — D3's one `UI tests` job running `PocketUI` becomes three shard jobs and a
  job named `UI tests` that is green only when all three are (D3, D4). The smoke on pull requests,
  the skipped required job on `main`, manual dispatch and the release rule stand. · ADR 0191 — its
  rejection of sharding across jobs is withdrawn: the warm build it wanted measured first is now
  9–10 minutes of every UI run. Its other reason, the cost of handing build products between jobs,
  is avoided rather than paid (D5). D1 (the cache) and D3 (parallel testing on cloned simulators)
  stay reverted. · ADR 0053 — three more plans, `PocketUIShard1` to `3` (D1). The plans before them
  and the target boundary stand.
- **Relates to:** 0255 (the UI tests are not a required check, and the release rule it set is what
  `UI tests` answers) · 0146 (the retry allowance and the retry report, now per shard) · 0133 (the
  required job is untouched)
- **Schema:** none.

## Context

Since ADR 0294 the whole UI suite runs once per merge, on `main`. On main's run of 2026-11-11 that
was one job of about 50 minutes: 39 minutes of tests, about 10 to build, and the rest to boot the
simulator and write the result bundle. The release rule waits on it: no release build until main's
UI job is green.

Splitting it was refused twice, both times for a reason that has since changed. ADR 0191 (2026-09-04)
put sharding off until a warm build had been measured. ADR 0255 (2026-10-17) kept one build per job
because the build was about 5 minutes. It is now 9–10.

Two facts set the shape. macOS minutes cost nothing here, since the repository is public. And GitHub
Free allows 5 concurrent macOS jobs (docs.github.com, *Actions limits*, read 2026-11-12). A pull
request uses two: the required job and the smoke.

## Decision

**D1 — Three shard plans, balanced on measured time.** `PocketUIShard1` and `PocketUIShard2` select
11 classes each. `PocketUIShard3` skips exactly those 22 and so runs everything else. Using main's
2026-11-11 times, each shard is 13.0 minutes of tests. Shards 1 and 2 begin with the two classes
that have always run first on `main`, `AddRoutineUnitSearchUITests` and `AddToRoutineUITests`. A
cold simulator is where the smoke's first run went wrong (ADR 0294 D2).

They are plans, not `-only-testing:` flags, for 0053's reason. Shard 3 is defined by what it skips so
that a new or renamed class lands in shard 3, not in no shard.

**D2 — `check-manual.py` C17 holds the three together.** Shard 3 has to skip exactly the classes 1
and 2 select. A class it skips that neither selects is one CI never runs, and every shard would still
go green. C17 fails on that, on a class selected by both, on entries that name single tests rather
than classes, and on a shard with nothing to run. It runs on every push, docs-only included, like the
rest of that script. Checked when it landed: it passes on the real plans and fails, naming the class,
on a class added to shard 3's skips alone and on a class added to two shards. `xcodebuild
-enumerate-tests` put the shards' tests together at exactly `PocketUI`'s 65, with none in two.

**D3 — One matrix job, `ui`.** `scope` decides its plans: `PocketSmoke` on a pull request, named
`UI smoke`, and otherwise the three shards, named `UI tests 1/3` to `3/3`. That keeps one copy of the
steps for both. `fail-fast` is off, so a red shard doesn't cancel the other two.

**D4 — `UI tests` is the verdict, on its own.** A job named `UI tests` on an Ubuntu runner needs the
shards and passes only if all of them passed. `scripts/main-ui-green.sh` reads that check by name,
so the release rule has one job to ask, as before. The job runs under `always()`, because without it
a failed or cancelled shard would *skip* the verdict. The script reads `skipped` as a docs-only
commit and would walk back past it to an older green. It is skipped only on a pull request and on a
docs-only change.

**D5 — Each shard builds the app itself.** Building once and handing the products on
(`build-for-testing`, an artifact, `test-without-building`) puts a build, an upload and a download in
front of every shard's tests. Three builds side by side cost three times the runner minutes, which
are free, and finish sooner.

**D6 — Three, not more.** Three shards and a pull request's two macOS jobs make five, GitHub Free's
limit. A fourth shard would queue whenever a pull request was running.

## Alternatives

- **Build once, test in shards.** Fewer minutes, a longer wait (D5). Revisit if minutes start to
  cost: a private repository, or a paid runner.
- **Four or more shards.** Each takes about 12 fixed minutes to boot and build. A fourth would cut
  the tests from 13 minutes to about 10, and it would queue behind any running pull request (D6).
- **Parallel testing on cloned simulators** (`-parallel-testing-enabled`). ADR 0191 D3 measured it
  slower and found it blinded the retry report. Separate runners have neither problem.
- **Shards listed by test rather than by class.** Finer balance. But C17's arithmetic only holds for
  whole classes, and one runner launches the app per test either way.
- **Shard 3 as a third selection.** Symmetric, and a class nobody lists would run nowhere. The skip
  list is what makes "nowhere" impossible.

## Consequences

- Main's UI run should take about 26 minutes instead of 50: about 12 to boot and build and 13 of
  tests on each runner, side by side. That figure is an estimate until the first run on `main` or a
  dispatch.
- Three result bundles per run, `UITestResults-PocketUIShard1` to `3`, each with its raw log, and a
  retry report per shard.
- Each shard pays the first-test cold start, where one run did before.
- **A class no longer runs after the ones it used to.** Each runner's simulator starts empty and
  only its own shard's classes write to it, so a test that relied on something an earlier class
  left in the store breaks when the two land on different runners. The first dispatch found one:
  `ReferenceFilingUITests` had only ever met a References library that something else had already
  added to. Empty, the library shows its own *Add a link* beside the ＋ menu's, and the test's query
  matched both. It now picks the menu's out by `UITestHooks.referencesEmptyAddLink`. A failure that
  appears only under sharding, with no app change behind it, should be read as this first.
- **The balance drifts.** New classes land in shard 3, so it grows. Rebalancing means moving classes
  between the lists, in all three plans together, and C17 says if the move left a gap.
- A push to `main` while a pull request runs uses all five macOS slots. A second pull request at the
  same moment queues.
- Each shard still boots its simulator before building. Booting during the build would save about
  2 minutes on every macOS job; that is a separate change.
