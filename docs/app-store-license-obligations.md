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

**Pocket's line:** Apple Music is browse/metadata only. The practice engine
never touches Apple Music audio, and Apple Music metadata is not persisted
beyond what a visible, directly-relevant feature needs.

### Audio recording indicator — §3.3.3.A
**Triggered by:** practice-take mic recording (ADR 0069, when built).

- Show a **reasonably conspicuous** indicator whenever recording is happening.
- The app may **not** be designed to record others without their awareness.
- Build the indicator into the recording UI from the first slice, not as polish.

### Content rights in bundled audio — §3.3.4.A
**Triggered by:** any seeded/demo/bundled audio or musical content shipped in the
app (not user-supplied files).

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

## Standing risks (not feature-gated)
- **Indemnification is broad (§10)** — including third-party IP and harmful-content
  claims. Argues for being conservative about any third-party or user-uploaded
  content the app displays or shares.
- **Apple's liability to you is capped at $50 (§13)**; software is "as is" (§12).
- **Apple can reject/remove the app or revoke certs at its discretion**
  (§6.9, §5.4).
- **No public screenshots/reviews of pre-release OS betas** (§9.1) — relevant to
  device beta testing.
