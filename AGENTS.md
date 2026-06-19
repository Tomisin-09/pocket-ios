# Working in this repo

Pocket is a **native iOS** app (Swift / SwiftUI, iOS 17+). This is not a web
project — there is no `npm`. The build is defined as code via XcodeGen
(`project.yml`); regenerate the Xcode project with `xcodegen generate` after
changing files or targets.

## Apple frameworks evolve — verify, don't assume

SwiftUI, SwiftData, MusicKit and AVFoundation change meaningfully between OS
versions, and APIs may differ from training data. Before writing against an
Apple framework, check the current API (Xcode docs / developer.apple.com) and
heed deprecations. Pin the deployment target in `project.yml` and write to it.

**Audio source reality:** Apple Music streaming audio is DRM-protected and
cannot be tapped for raw PCM (waveform / time-stretch). The practice engine is
built on DRM-free **local / iCloud files**; Apple Music is browse/metadata only.
See `docs/decisions/0001-audio-source-local-first.md`. Do not reintroduce an
Apple-Music-as-waveform-source assumption without revisiting that ADR.

# Pre-push checklist

Run these before every commit that touches app code. Do not push until all pass.

1. **Lint** — `swiftlint`. Fix all errors. Suppress only with
   `// swiftlint:disable:next <rule>` on the exact line, never file-wide.
2. **Build** — `xcodebuild build -scheme Pocket -destination 'generic/platform=iOS Simulator'`.
   Fix all errors and warnings. This catches breakage in files with no test
   coverage — do not skip it.
3. **Tests** — `xcodebuild test -scheme Pocket -destination 'platform=iOS Simulator,name=iPhone 15 Pro'`.
   When adding or changing a feature, update the relevant test. When adding a
   new module with non-trivial logic, add a test under `PocketTests/`. Pure,
   UI-free logic (tempo math, slider mapping, automator stepping, planner
   weighting, identity) MUST be unit-tested — that's the logic that breaks
   silently otherwise.
4. **Docs** — after any significant change, review the table below and update
   every affected file. Do not skip this step.

   | File | Update when… |
   |---|---|
   | `CHANGELOG.md` | Any user-visible change — add an entry to `[Unreleased]` |
   | `PROJECT.md` | New/changed screen, data model, service, entitlement, env/config, or architecture decision |
   | `docs/architecture.md` | New/changed module, audio pipeline stage, persistence/sync change, or third-party service |
   | `docs/decisions/` | Any decision that closes off an alternative (new ADR, numbered) |
   | `docs/design-brief.md` | Changes to the design system/tokens, screen inventory, or the design working protocol |
   | `README.md` | Changes to project structure, build/CI, or the "How it works" summary |

   **What counts as significant:** new screen, new model/service, schema or
   persistence change, removed behaviour, new entitlement or permission string,
   new build config / env var, infrastructure change. Pure refactors that don't
   change observable behaviour need only `CHANGELOG.md`.

# Conventions

- **Branches:** `pocket-0XX-short-title` (zero-padded, incrementing). Create the
  branch before editing; don't work on `main`.
- **Permissions:** never add an `Info.plist` usage string or entitlement the app
  doesn't actually exercise — over-broad permissions cause rejection.
- **Secrets:** no API keys in the client, ever. The Claude API key lives only in
  the backend proxy (see `infrastructure/`). The app talks to a base URL chosen
  by build configuration (Debug → local/dev proxy, Release → prod).
- **Pure logic stays pure:** keep tempo/identity/planner logic free of SwiftUI
  and AVFoundation imports so it stays unit-testable.

# Commit / PR

- Don't push or open PRs unless asked. If on `main`, branch first.
- After push/PR, wait for CI to be confirmed green before merging; don't poll in
  a loop.