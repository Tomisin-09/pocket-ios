# ADR 0133 — A docs-only change skips the work, never the check

- **Status:** Accepted — built on `pocket-213-docs-only-ci-fast-path`
- **Date:** 2026-07-31 (`pocket-213-docs-only-ci-fast-path`)
- **Builds on:** ADR 0053 (the `PocketLogic` / `PocketAll` test-plan split — this decides *whether* the
  plan runs, not which one).

## Context

Every PR waits on one required status check, `Lint · Build · Test`, which installs three Homebrew
tools, regenerates the Xcode project, lints, then builds and runs the full `PocketAll` plan on a
`macos-15` runner. That is roughly seven minutes, most of it queue time for a scarce macOS runner.

`main` is protected with `strict: true` (branch must be current) and `enforce_admins: true`, so there
is no direct-push escape hatch. A change that touches nothing but `docs/decisions/0132-*.md` pays the
same seven minutes as one that rewrites the audio engine — and this repo produces a *lot* of
documentation-only commits, because the working agreement requires ADRs, a CHANGELOG entry, and
`PROJECT.md` upkeep as separate, reviewable steps.

The obvious fix is a `paths-ignore` filter on the workflow's `on:` trigger. **It is a trap, and it
would be discovered only after it had deadlocked a PR.** Branch protection requires the *context*
`Lint · Build · Test` to report success. If the workflow does not trigger, the check never reports,
and the PR sits on "Expected — waiting for status" forever. `paths-ignore` does not make a docs PR
fast; it makes it unmergeable. The same hazard sits behind renaming the job.

There is a second, quieter problem. `scripts/pre-push.sh` already had a local docs fast path, but it
asked a different question: it skipped the build when nothing matched a *denylist of buildable
extensions* (`.swift`, `project.yml`, `.xcconfig`, `.entitlements`, `Info.plist`, `.swiftlint.yml`).
That list is incomplete, and silently so — a change to `PocketAll.xctestplan`, to an asset catalog, or
to a future `Package.swift` skipped the local build entirely and went to CI unverified. A denylist
gets this wrong the first time the repo grows a file type nobody thought to add.

## Decision

### 1. The job always runs; the steps are what get skipped

`lint-build-test` keeps its name verbatim and stays unconditional, so the required check always
reports. A preceding `scope` job decides whether the change is documentation-only, and every
expensive step carries `if: needs.scope.outputs.docs_only != 'true'`. Branch protection is satisfied
by a real job that genuinely ran, not by the skipped-job loophole.

The name is now load-bearing in a way it wasn't before, so it carries a comment saying so.

### 2. The scope decision picks the runner, which is where the time actually is

`runs-on` is an expression:

```yaml
runs-on: ${{ needs.scope.outputs.docs_only == 'true' && 'ubuntu-latest' || 'macos-15' }}
```

Skipping the steps alone would still queue and boot a macOS runner to do nothing. A docs-only PR now
resolves on `ubuntu-latest` in about twenty seconds. This is the whole saving; the `if:` guards are
what make it *correct*, the runner switch is what makes it *fast*.

### 3. One rule, one file, shared by CI and the hook

`scripts/docs-only.sh <base> <head>` prints `true` or `false` and is the only definition of
"documentation". CI calls it; `pre-push.sh` calls it. They cannot drift, because there is nothing to
drift from.

### 4. Documentation is a narrow allowlist, and everything else is code

Docs are: Markdown anywhere (`**/*.md` — `CHANGELOG.md`, `PROJECT.md`, `AGENTS.md`, `README.md`,
`docs/decisions/*.md`), anything under `docs/` (which sweeps in the static `docs/site/*.html` support
and privacy pages, not part of the Xcode build), and `LICENSE`.

Everything else runs the full job — including `.github/workflows/**`, which is deliberate: a workflow
edit is precisely the change you want CI to exercise.

The allowlist direction is the point. A wrong "this is code" costs minutes; a wrong "this is docs"
costs a broken `main`. The asymmetry decides the shape.

### 5. Every uncertainty resolves to "run everything"

An unresolvable base (shallow clone, force-push, a branch's first push), a missing argument, an empty
diff, a failed `git diff` — all print `false`. The script never fails the push; it only ever declines
to skip.

### 6. The hook now skips lint too, not just the build

Under the old denylist the hook still ran `xcodegen` and `swiftlint --strict` on a docs-only push.
Under the narrow allowlist, nothing lintable can have changed, so the hook exits before either. A
docs-only push is now instant locally as well, and matches what CI will do.

## Consequences

- Docs-only PRs: ~7 min → ~20 s, and no macOS runner is consumed.
- The hook gets *stricter* for some changes it used to wave through — an `.xctestplan` or asset-catalog
  edit now builds locally. That is the bug fix, not a regression.
- A workflow-file-only edit now runs the full macOS job locally and on CI. Accepted: rare, and it is
  the change most worth verifying.
- `Lint · Build · Test` will start showing as green from an Ubuntu runner on docs PRs. Anyone reading
  the log will find the "Documentation-only change" line saying why.
- The required-check name is now referenced from a comment in the workflow. If branch protection is
  ever renamed, both must move together.

## Alternatives considered

- **`paths-ignore` on the `on:` trigger.** The trap described above: the required check never reports
  and the PR is permanently unmergeable. Rejected outright, and documented here so it isn't
  rediscovered as a "simplification".
- **A second job with the same name, skipped via a job-level `if:`.** Relies on GitHub treating a
  skipped job as a satisfied required check. It works today, but it is a loophole rather than a
  statement, it produces two checks with one name, and it reports success for a job that never ran.
- **`dorny/paths-filter`.** A third-party action for a nine-line `git diff`, on the one workflow that
  gates every merge. Not worth the supply-chain surface.
- **Keeping the hook's denylist and giving CI its own allowlist.** Two rules, one of them known-wrong,
  guaranteed to diverge. Rejected in favour of the shared script.
- **Dropping the required check for docs PRs by hand (admin merge).** `enforce_admins` is on
  deliberately; routing around it by policy would erode the reason it is on.
