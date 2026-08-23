# Pocket

A native iOS guitar-practice app. Pocket attaches practice data — loops, markers,
notes, routines — to the songs in your music library, keeping everything you've
worked on in one place.

> **Status:** Phase 1. The **waveform practice screen** is built — real audio engine,
> seamless click-free looping, pinch-to-zoom — loops/markers now **persist** (SwiftData),
> and you can **import audio files** into a **song library** to practice with their real
> waveform. The app opens on a **home hub** (greeting · resume card · metronome · your songs).
> The practice planner, AI, and backend come next. See `PROJECT.md` for the current
> state.

## How it works

- Practice data attaches to a stable `SongRef` identity, so it survives across
  launches and (later) syncs across devices via CloudKit.
- The waveform / speed / loop engine runs on **DRM-free local and iCloud files**.
  Apple Music streaming audio is DRM-protected and can't be tapped for waveform or
  time-stretch, so it is never a practice source. See
  `docs/decisions/0001-audio-source-local-first.md`.
- **v1 ships no Apple Music access at all** — no MusicKit, no `MPMediaLibrary`, and
  therefore no `NSAppleMusicUsageDescription`. Browse/metadata is the *most* that
  ADR 0001 would ever permit, not something that exists today; `SongRef.appleMusic`
  is a dormant model seam constructed only in tests. Build the browse path and the
  usage string goes back in the same commit.
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

### Run on a physical iPhone

Audio can't be heard in the Xcode `#Preview` canvas (it skips the engine), so
test sound on-device. With the iPhone plugged in, unlocked, and Developer Mode
on:

```sh
scripts/run-device.sh        # incremental build → install → launch
scripts/run-device.sh -n     # skip build; just install + launch the existing .app
```

First launch needs a one-time Trust: Settings → General → VPN & Device
Management → Developer App → Trust.

### Refreshing the brand artwork

The designer ships one SVG lockup per appearance; the app needs three different
crops of it (full lockup, crescent-only mark, wordmark-only). Those are
generated, not hand-cropped — after a new logo revision:

```sh
scripts/derive-brand-svgs.py                     # light + dark → the asset catalog
scripts/derive-brand-svgs.py --app-icon          # …and re-render the 1024² App Icon
scripts/derive-brand-svgs.py --pro-wordmark      # …and re-crop the paywall's "Red Moon PRO"
scripts/derive-brand-svgs.py --out /tmp/preview  # preview crops, catalog untouched
```

The **Pro wordmark** is the exception to "one lockup, three crops": it arrives as
a pair of transparent PNG exports rather than a lockup SVG, so there are no path
ids to crop by and it is cropped by its **alpha channel** instead — tight to the
ink, then area-resampled down. Point `--pro-source` at the folder holding the
pair (default `~/Documents`).

Point `--source` at the revision's folder if it moves. The App Icon is the same
mark composited on an opaque near-black square and rasterised via QuickLook — it
has to stay PNG, because App Store icons must be opaque 1024² with no alpha
channel, which the script asserts before writing.

## Pre-push checks

See `AGENTS.md`. In short: `swiftlint` → `xcodebuild build` → `xcodebuild test`
→ update docs. CI enforces the same on every PR.

`xcodebuild test -scheme Pocket` runs the default **`PocketLogic`** test plan —
the ~498 unit tests, no coverage — for a fast local loop (~59s vs ~123s for the
full suite). CI runs the full **`PocketAll`** plan (`-testPlan PocketAll`, adds
the UI tests + coverage). A third plan, **`PocketShoot`**, holds the user manual's
screenshot classes; it is driven only by `scripts/shoot-manual.sh` and is skipped
by `PocketAll`. See `docs/decisions/0053`.

## Project layout

```
Pocket/
  App/         App entry, root scene
  Features/    Home · Library · Waveform · Metronome · Practice · Repertoire
  Core/        Audio (engine + pure tempo math) · Models · Services · Export (ADR 0181) · Storage
  UI/          Shared components, design tokens
  Resources/   Info.plist, PrivacyInfo.xcprivacy
PocketTests/      Unit tests (pure logic)
PocketUITests/    XCUITest flows
infrastructure/  Terraform for the Phase 4 Claude proxy (prod)
docs/          architecture.md, positioning.md (who we're up against and the line we take), decisions/ (ADRs), manual/ (user manual), practice-techniques.md, research/ (3rd-party refs, git-ignored raw)
```

## CI/CD

- **On PR:** SwiftLint + build + test — full `PocketAll` plan (`.github/workflows/ci.yml`).
  A documentation-only change (`**/*.md`, `docs/**`, `LICENSE`) skips all three and finishes in
  ~20s on a Linux runner — the required check still reports, it just has nothing to do. The rule
  lives in `scripts/docs-only.sh` and is shared with the pre-push hook. See `docs/decisions/0133`;
  note in particular why the workflow must *not* grow a `paths-ignore` filter.
- **The manual check** (`docs/decisions/0165`): `scripts/check-manual.py` holds `docs/manual/` to
  what the app's compiled catalogs actually say. It is the one step with no `if:` on it — a
  docs-only change is exactly what it guards, and exactly what switches everything else off. Stdlib
  Python, no dependencies, so it runs on either runner; it sits inside `lint-build-test` rather than
  in `scope` or a job of its own, for the reason 0133 gives.
- **Flake control** (`docs/decisions/0146`): the UI tests wait on a readiness signal the app raises
  when first-launch seeding completes, not on a guess about how slow the runner is — every test
  launches through `UITestCase.launchApp()`, which carries the one generous wait. CI also boots and
  settles the simulator before the timed run and retries only failed tests
  (`-retry-tests-on-failure -test-iterations 2`). Because retrying hides flakes by design,
  `scripts/report-test-retries.sh` annotates the PR with every test that needed one — **a green run
  with retries in it is not a clean run.** The pre-push hook pre-boots too but deliberately does not
  retry.
- **Debugging a CI-only failure:** every run uploads a **`TestResults`** artifact — the
  `.xcresult` bundle plus the raw `xcodebuild` log — and it uploads on red runs too, which are the
  ones worth downloading. Grab it from the run's summary page and open the bundle in Xcode for the
  failure's screenshots and attachments. Without it the only way to chase a test that passes locally
  and fails on the runner is a guess per ~11-minute round, which is how one UI test came to be
  deleted rather than fixed.
- **On merge to `main`:** TestFlight via Fastlane (`.github/workflows/testflight.yml`).
- Backend prod is AWS (Lambda + API Gateway); dev runs locally / off-AWS.