---
description: Run the Pocket pre-push checklist (lint, build, test) on Sonnet
model: sonnet
effort: medium
disable-model-invocation: true
allowed-tools: Bash
---
Run the AGENTS.md pre-push checklist for Pocket and report a concise pass/fail summary per step. Do NOT push.

0. If `project.yml` or any files/targets changed since last generate, run `xcodegen generate` first.
1. **Lint** — `swiftlint`. Fix all errors. Suppress only with a line-scoped `// swiftlint:disable:next <rule>`, never file-wide. Watch identifier_name (≥3 chars) and file_length (≤400 lines).
2. **Build** — `xcodebuild build -scheme Pocket -destination 'generic/platform=iOS Simulator'`. Fix all errors AND warnings.
3. **Tests** — `xcodebuild test -scheme Pocket -destination 'platform=iOS Simulator,name=iPhone 17'`. (The iPhone 15 Pro sim in AGENTS.md isn't installed — use iPhone 17.)

Note: CI runs Swift 6 / Xcode 16 and is stricter than local — main-actor isolation issues can pass locally but fail CI. End with a one-line pass/fail summary for each of the three steps.
