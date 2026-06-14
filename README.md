# Pocket

A native iOS guitar-practice app. Pocket attaches practice data — loops, markers,
notes, routines — to the songs in your music library, keeping everything you've
worked on in one place.

> **Status:** Phase 0 scaffold. The practice engine, screens, and backend are
> built in later phases. See `PROJECT.md` for the current state and the build
> plan for sequencing.

## How it works

- Practice data attaches to a stable `SongRef` identity, so it survives across
  launches and (later) syncs across devices via CloudKit.
- The waveform / speed / loop engine runs on **DRM-free local and iCloud files**.
  Apple Music is browse/metadata only — its streaming audio is DRM-protected and
  can't be tapped for waveform or time-stretch. See
  `docs/decisions/0001-audio-source-local-first.md`.
- AI session suggestions (later) run through a backend proxy that holds the API
  key; the app never does. See `docs/decisions/0002-ai-proxy-backend.md`.

## Getting set up

Requires Xcode 16+ and these tools (install via Homebrew / Mint):

```sh
brew install xcodegen swiftlint
# Fastlane (for signing + TestFlight):
brew install fastlane   # or: gem install fastlane
```

Generate the Xcode project and open it:

```sh
xcodegen generate
open Pocket.xcodeproj
```

## Pre-push checks

See `AGENTS.md`. In short: `swiftlint` → `xcodebuild build` → `xcodebuild test`
→ update docs. CI enforces the same on every PR.

## Project layout

```
Pocket/
  App/         App entry, root scene
  Features/    Library · Waveform · Planner · Repertoire
  Core/        Audio (engine + pure tempo math) · Models · Services
  UI/          Shared components, design tokens
  Resources/   Info.plist, PrivacyInfo.xcprivacy
PocketTests/      Unit tests (pure logic)
PocketUITests/    XCUITest flows
infrastructure/  Terraform for the Phase 4 Claude proxy (prod)
docs/          architecture.md, decisions/ (ADRs)
```

## CI/CD

- **On PR:** SwiftLint + build + test (`.github/workflows/ci.yml`).
- **On merge to `main`:** TestFlight via Fastlane (`.github/workflows/testflight.yml`).
- Backend prod is AWS (Lambda + API Gateway); dev runs locally / off-AWS.