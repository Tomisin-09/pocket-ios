# 0064 — V2 social layer: boundaries and privacy-by-design constraints

- **Status:** Accepted (2026-07-05)
- **Date:** 2026-07-05

## Context

The V2 vision (2026-07-05) points the product at a social layer: shared practice
stats, leaderboards and an end-of-year recap (Strava-style), user-shared
exercise routines, and — the most sensitive idea — shared *loops* with a
compensation model ("a kind of streaming agreement"). Guitar teachers were
identified as the persona with the most to gain from sharing their own
exercises. The same vision asks for a privacy-by-design approach and a robust
data strategy before anything backend-shaped is built.

Pocket today is deliberately **local-first and single-player**: practice data
lives in SwiftData on-device (CloudKit *personal* sync planned, ADR 0011 /
PROJECT.md Phase 4), the only planned backend is the thin AI proxy (ADR 0002,
paper-only), and the app ships zero networking in V1. A social layer is not a
feature on top of this — it is a second product surface with accounts,
moderation, and regulatory obligations. The cheap thing to do now is to fix the
boundaries that keep the pivot buildable without poisoning the V1 substrate.

A loop is a *pointer into a copyrighted recording* (start/end over an imported
file). Sharing loops — or paying users for shared loops — means distributing,
or monetising, slices of audio the sharer does not own. That is a licensing and
piracy-policing problem the product has no capacity to solve, and the vision
itself flags the hesitation.

An exercise, by contrast, is a **pure practice recipe** — name, description,
tempo fields, meter, ramp shape (`CommandRamp` recipe). It contains no audio,
no waveform, no file reference. It is the one unit in the model that can be
shared with zero rights exposure — and it is exactly what the teacher persona
wants to share.

## Decision

1. **Local-first is permanent, social is additive and opt-in.** The V1 feature
   set must remain fully functional with no account and no network, forever.
   No existing feature may grow an account requirement. Social surfaces are
   opt-in individually (sharing stats does not opt you into leaderboards, etc.).

2. **The shareable unit is the *exercise*, never the loop.** Community sharing
   ships exercises only: the recipe fields, no audio, no bookmarks, no song
   references. Loop sharing and any creator-compensation model are **out of
   scope for V2** — not "later this year", but a separate decision that would
   need its own rights framework to reopen (this ADR closes it until then).

3. **Stats sharing and leaderboards use derived numbers only.** What leaves the
   device is the `PracticeStats`-style layer — counts, streaks, tempo
   achievements, minutes — never audio, waveforms, file names, bookmarks, or
   journal text. Journals are private, full stop.

4. **Sign-up is light and Apple-first.** Sign in with Apple is the identity
   path (no password store, no email-verification funnel); an account is
   created only at the moment a social action needs it.

5. **Personal sync and social share ride different rails.** Personal practice
   data syncs via CloudKit (private database, Apple-managed, already the ADR
   0011 plan). The social backend (an extension of the ADR 0002 AWS footprint)
   holds **only** what was explicitly shared: profile, shared exercises,
   opted-in stats. Personal practice data never transits the social backend.

6. **Privacy-by-design rules bind every social slice:**
   - Data minimisation: a slice may collect only the fields its surface shows.
   - Every new off-device data type adds its `PrivacyInfo.xcprivacy`
     `NSPrivacyCollectedDataTypes` entry *in the same PR* (standing backlog rule).
   - Account deletion and data export are designed **before** the first byte is
     collected (UK GDPR / App Store 5.1.1(v) both require it; retrofitting is
     how apps get rejected).
   - Shared content is revocable: unsharing an exercise removes it from the
     backend, not just the UI.

7. **Keep the desktop/bulk-edit door open (build nothing).** Song metadata
   editing logic stays pure and portable (`Labels`, `MusicalKey`, etc. already
   are); no new model logic may assume "the editor is this one iPhone screen".
   That is the entire cost accepted now; a desktop app remains unplanned.

## Consequences

- **What a social V2 build actually needs** (sized in
  `docs/research/v2-backend-and-data-strategy.md`): Sign in with Apple auth,
  a profile + shared-exercise store, a stats-ingest path for leaderboards, a
  report/moderation flow for shared content, and the deletion/export plumbing.
  Nothing else — the loop-content pipeline, payments, and rights policing are
  all avoided by decision 2.
- **The teacher persona is served early** (shared exercises are the smallest
  social slice) without touching the hardest problem (audio rights).
- **Streaming-platform integration stays out** (reaffirming ADR 0001): song
  addition remains local/iCloud files. If the product later earns the scale to
  negotiate streaming access, that is a new ADR against 0001, not a drift.
- Leaderboard integrity (fake practice minutes) is accepted as a *social*
  problem, not solved with surveillance — no play-verification telemetry.
- The recap ("end-of-year stats compile") is derivable client-side from local
  data; it needs the backend only if shared, which keeps it buildable early.
