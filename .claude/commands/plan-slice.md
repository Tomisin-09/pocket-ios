---
description: Design-only planning for the next slice on Opus, high effort — no code written
model: opus
effort: high
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
---
Plan the next slice of work WITHOUT writing or editing any code. This is design only — the goal is to decide before building, because rework is the most expensive thing.

Topic / feature for this slice: $ARGUMENTS

Before scoping:
- Recover any existing plan for this work first — search memory, `docs/decisions/`, `docs/backlog.md`, and `gh issue list`. Do NOT invent scope when a plan already exists.
- Check what's in flight: current branch, `git log main..HEAD`, `gh pr list --state open`. Surface any unmerged prior slice and confirm sequencing (merge first vs. deliberately stack) before planning new code.
- Verify "done" labels against the actual code/files before building on them — "done" is a claim, not ground truth.

Then produce:
1. Scope — what's in, and what's explicitly out.
2. Whether a new ADR is needed (a decision that closes off an alternative) and its outline.
3. The pure, UI-free logic units that MUST be unit-tested (tempo/identity/planner/automator/slider math).
4. Files likely touched + the branch name (`pocket-0XX-short-title`).
5. Open questions for me to answer before any code is written.

Output the plan for review. Do NOT start implementing.
