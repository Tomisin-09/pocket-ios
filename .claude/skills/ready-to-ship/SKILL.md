---
name: ready-to-ship
description: Run a full pre-launch / App Store readiness audit of the Pocket iOS app on demand. Use when the user asks "is it ready to ship", "ready-to-ship", "pre-launch audit", "would this pass App Store review", "App Store readiness", or triggers /ready-to-ship. Internal skill, this repo only.
---

# Ready-to-Ship — Pocket pre-launch audit

Internal skill for the Pocket iOS app. Manually triggered. Produces a single
prioritised report: would this pass Apple review, what's fragile, what's dead
code. Does **not** make changes — it reports. The user decides what to act on.

This skill is the standing bar referenced in `docs/backlog.md` →
"Launch readiness". When it changes (new Apple rules, new required-reason APIs),
update both this file and that section together.

## How to run

Work through the five phases below in order. Run independent shell checks in
parallel. Build and tests are slow — kick them off in the **background** first,
do the static analysis while they run, then fold their results in. Read the
findings critically: most `try?` / `try!` hits are benign; the job is to
separate real risk from noise, not to dump grep output.

### Phase 1 — Mechanical sweeps (start build + tests in background first)

```bash
# Background (slow): regenerate, build for warnings, run the suite.
xcodegen generate
xcodebuild build -scheme Pocket -destination 'generic/platform=iOS Simulator' \
  2>&1 | grep -E 'warning:|error:' | sort | uniq -c | sort -rn
xcodebuild test -scheme Pocket -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | grep -E 'Test Suite .* (passed|failed)|Executed .* tests|\*\* TEST'
```

- **Lint:** `swiftlint lint --strict` — must be 0 violations.
- **Build:** 0 warnings / 0 errors. The "No AppIntents.framework dependency
  found" metadata note is harmless — ignore it.
- **Tests:** `** TEST SUCCEEDED **`, 0 failures. A green suite is part of "no
  paper tape" — don't skip it.
- Sim destination is **iPhone 17** (iPhone 15 Pro from AGENTS.md isn't installed).

### Phase 2 — Fragility audit (static)

Grep, then **read each hit in context** before flagging:

- `try!` — acceptable only inside `#Preview` `ModelContainer` setups. Anywhere
  else is a flag.
- Force-unwrap (`x!`), `as!`, `fatalError`/`preconditionFailure` — should be
  none in app code. Any hit is a flag.
- `try?` — benign for `Task.sleep` (cancellation), audio-session teardown, and
  fail-safe cache writes. A flag when it swallows a real error over **user data**
  (a `context.save()` of loops/markers/journal) or silently disables a core
  feature (audio session / engine start with no user signal).
- `print(` — none in shipping code.
- Debt markers: `TODO|FIXME|HACK|XXX|WORKAROUND` — none expected.

### Phase 3 — Dead-code hunt

- Filename-based "unused type" greps are **unreliable** for `+Extension.swift`
  and View files (the bare filename never appears as a token). Confirm a real
  type name from the file before declaring it dead.
- Check the app entry (`Pocket/App/PocketApp.swift`) for what's actually
  rendered; scaffolds/placeholders not reachable from it are dead (e.g. the
  Planner `HomeView` Phase-0 scaffold).
- Cross-reference parked features in `docs/backlog.md` — parked ≠ dead, but a
  parked feature with code still in the tree is worth surfacing.

### Phase 4 — App Store compliance

- **App icon / asset catalog (hard blocker):** an `AppIcon` set must exist
  (`find . -name '*.xcassets'`; check the built `.app` for an icon/`.car`). No
  icon = guaranteed rejection and App Store Connect won't accept the build.
- **Privacy manifest** (`Pocket/Resources/PrivacyInfo.xcprivacy`): must match
  reality. Check for **undeclared required-reason APIs** —
  `systemUptime`/`mach_absolute_time`/`CACurrentMediaTime` (boot-time category),
  `modificationDate`/`creationDate` (file-timestamp), disk-space APIs,
  UserDefaults/`@AppStorage`. Note: tap-tempo uses **song-time seconds**, not
  wall-clock, so it needs no boot-time declaration — verify this still holds.
  Any off-device data send (AI phase) needs `NSPrivacyCollectedDataTypes`.
- **Permissions** (`Info.plist`): every usage string must map to a shipping
  feature; flag any that don't. Confirm there's no mic string while the pedal
  modeller is parked.
- **Background modes:** `audio` is justified by screen-off practice playback —
  confirm the app actually plays in the background (else it's a rejection).
- **Entitlements:** should claim nothing ahead of the feature that needs it.
- **`ITSAppUsesNonExemptEncryption`** in `Info.plist`: should be `false` (no
  custom crypto) to skip the per-upload export-compliance prompt.
- **Secrets:** no API keys in the client (the Claude key lives only in the
  backend proxy). Grep for key/secret/bearer patterns.
- **Release config:** `MARKETING_VERSION` should be a real release version
  (not `0.0.1`); the Release `POCKET_API_HOST` placeholder is fine *only* while
  there's zero live networking — verify no `URLSession`/`URLRequest` ships V1.

### Phase 5 — Report

Single prioritised report, severity-tagged:

- 🔴 **Blocker** — submission will be rejected or can't be uploaded.
- 🟠 **Should-fix** — accepted but sloppy (export prompt, version string).
- 🟡 **Minor/optional** — dead code, defensive-robustness nits.
- ✅ **Clean** — explicitly list what passed, so "ready to ship" is evidenced,
  not asserted.

End with a suggested order of operations and which items (if any) need a human
(e.g. icon artwork). Default to **reporting only** — do not edit app code unless
the user asks.
