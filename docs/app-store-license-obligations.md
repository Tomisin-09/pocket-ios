# App Store license-agreement obligations

Tracks the Apple Developer Program License Agreement (ADPLA) clauses that bind
concrete Pocket features, so the obligation is visible against the feature that
triggers it. Not legal advice — a working checklist. Clause numbers reference the
ADPLA reviewed 2026-07-09.

## How to use this
When you build or change a feature listed under "Triggered by," re-check the
matching obligation. When you add a feature that touches audio recording, Apple
Music, user data, bundled content, or payments, add a row.

## Obligations

### MusicKit / Apple Music — Attachment 3.3.6.D
**Triggered by:** any Apple Music browse/metadata use. Reinforces
[ADR 0001](decisions/0001-audio-source-local-first.md).

**Currently NOT triggered — v1 uses no MusicKit at all.** There is no MusicKit
import, no `MPMediaLibrary`/`MPMediaPicker`, and `SongRef.appleMusic` is
constructed only in tests. `MediaPlayer` is imported solely for
`MPRemoteCommandCenter` / `MPNowPlayingInfoCenter` (lock-screen transport), which
is not MusicKit and needs no permission. `NSAppleMusicUsageDescription` was
removed from `Info.plist` during submission prep for exactly this reason.

Re-read the list below the moment anyone proposes an Apple Music browse path —
and re-add the usage string in that same commit:

- Do **not** download, upload, or modify MusicKit content.
- Do **not** cache MusicKit content, and do **not** sync it with any other content.
- Do **not** charge for, or indirectly monetize, access to Apple Music (no IAP,
  ads, or gating built on it).
- If you offer playback, it must be **full songs** with standard play/pause/skip
  controls (no previews-as-product, no misrepresenting the controls).
- Only render MusicKit content **through** the MusicKit APIs — album art and
  music text may not be used separately from playback/playlist management.
- User metadata (playlists, favorites) may be used only for a clearly-disclosed
  feature directly relevant to the app.
- Follow the Apple Music Identity Guidelines when displaying anything.

**Pocket's line, if it is ever built:** Apple Music would be browse/metadata only.
The practice engine never touches Apple Music audio, and Apple Music metadata is
not persisted beyond what a visible, directly-relevant feature needs.

### Audio recording indicator — §3.3.3.A
**Triggered by:** practice-take mic recording (ADR 0069, when built).

- Show a **reasonably conspicuous** indicator whenever recording is happening.
- The app may **not** be designed to record others without their awareness.
- Build the indicator into the recording UI from the first slice, not as polish.

### Content rights in bundled audio — §3.3.4.A
**Triggered by:** any seeded/demo/bundled audio or musical content shipped in the
app (not user-supplied files).

**Currently NOT triggered.** ADR 0148 §7 deleted the bundled demo track, so the app
ships **no** recorded audio at all. The one demo the app can still produce is
`Song.sample()` — a tone *generated at runtime* by `SampleToneGenerator`, embodying
no master recording and no composition of anyone else's. The App Store Connect
**Content Rights** answer is therefore "no third-party content".

Re-read this section the moment anyone proposes bundling a track again:

- Master recordings and compositions embodied in the app must be **wholly owned
  by you or licensed fully paid-up**, with no per-play fees owed by Apple or you.
- User-supplied local/iCloud files are the user's responsibility; shipped content
  is yours to clear.

### Privacy & user data — §3.3.3
**Triggered by:** any data collection, journal/notes sync, analytics.

- Ship a **privacy policy** (in-app and/or on the store listing).
- Get consent before collecting user/device data; use it only for a
  directly-relevant purpose.
- No permanent device-based identifier used to uniquely identify a device.
- Only declare Info.plist usage strings / entitlements the app actually exercises
  (already enforced in AGENTS.md).

### AI usage — §3.2(h)
**Triggered by:** the Claude-backed features via the backend proxy
([ADR 0002](decisions/0002-ai-proxy-backend.md)).

- Don't use AI to generate infringing or harmful content.
- Don't use one provider's model output to train another model.
- Secrets stay in the backend proxy only (already enforced in AGENTS.md).

### Paid features / IAP — Schedule 2
**Triggered by:** charging for anything (e.g. a premium planner tier).

- The base agreement covers **free** apps only. Before charging, separately
  accept **Schedule 2**; all in-app purchases must flow through Apple's IAP
  system (subject to commission).

### Terms of Use (EULA) — App Review Guideline 3.1.2 / Schedule 2
**Triggered by:** shipping any Terms link, and required once auto-renewable
subscriptions ship (Red Moon Pro, [ADR 0112](decisions/0112-freemium-monetization-and-pro-tier.md)).

- **Decision (2026-07-23): no custom Terms of Service until the Oracle AI tier
  introduces its own service relationship.** Apple's [standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/)
  applies by default and satisfies the required "Terms of Use (EULA)" link for
  both the free app and the Pro subscription. Don't re-litigate writing a custom
  ToS for v1 or Pro.
- **When Pro ships:** the paywall and the App Store description must both carry a
  functional **Terms of Use (EULA)** link (Apple's standard URL is acceptable)
  **and** a Privacy Policy link, plus the subscription disclosure text (title,
  duration, price/period, auto-renewal). The Terms link already ships in
  **Settings → About** (`SettingsView.appleStandardEULA`).
- **When Oracle AI ships:** write a custom ToS (acceptable-use for the proxy,
  liability disclaimer for AI output, England & Wales jurisdiction) and repoint
  the link. See [ADR 0092](decisions/0092-ai-strategy-boundaries-and-foundations.md).

### Privacy Policy link & hosting — §3.3.3 / Guideline 5.1.1
**Triggered by:** App Store Connect (privacy-policy URL is mandatory) and the
in-app link.

- **Source of record:** [docs/privacy-policy.md](privacy-policy.md) — standalone
  Red Moon Practice policy with the real controller details (Deco Operations Ltd,
  company 17032490, ICO ZC112793).
- **In-app link:** ships in **Settings → About** (`SettingsView.privacyPolicy`),
  currently pointed at the live `decooperations.co.uk/privacy#red-moon-practice`
  anchor.
- **To deploy standalone:** [docs/site/redmoon-privacy.html](site/redmoon-privacy.html)
  is deploy-ready. When it's live on the company site, repoint both the Settings
  link and the App Store Connect privacy URL at its dedicated URL.
- **Keep it true:** the policy no longer promises zero collection — ADR 0120
  replaced that with **"your playing never leaves your device"** plus opt-in,
  off-by-default anonymous usage counts. A crash reporter, Sign in with Apple, or
  the AI proxy would each break the revised wording too — update the policy **and**
  the App Privacy label *before* such a feature ships.

### Aptabase Swift SDK — MIT
**Triggered by:** the analytics pipeline (ADR 0120). The project's only
third-party dependency, pinned to an exact version in `project.yml`.

- MIT requires the copyright notice and permission text be included with
  "substantial portions" of the software. Swift Package Manager vendors the
  licence file into the build, which satisfies this for a binary distribution;
  no in-app acknowledgements screen is required.
- The SDK ships **its own `PrivacyInfo.xcprivacy`** (Product Interaction, not
  linked, not tracking, purpose Analytics). Our app manifest mirrors it exactly —
  if theirs changes on an upgrade, ours must be re-checked, which is one reason
  the version is pinned rather than ranged.

**Pocket's line:** an exact-version pin, because this is the only component that
can send data off-device; an upgrade is a deliberate reviewed act.

## Standing risks (not feature-gated)
- **Indemnification is broad (§10)** — including third-party IP and harmful-content
  claims. Argues for being conservative about any third-party or user-uploaded
  content the app displays or shares.
- **Apple's liability to you is capped at $50 (§13)**; software is "as is" (§12).
- **Apple can reject/remove the app or revoke certs at its discretion**
  (§6.9, §5.4).
- **No public screenshots/reviews of pre-release OS betas** (§9.1) — relevant to
  device beta testing.
