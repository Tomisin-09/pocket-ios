# V2 backend resources & data strategy (research, 2026-07-05)

Companion to **ADR 0064** (social-layer boundaries). This is the sizing map:
what backend has to exist for each V2 social slice, what data each slice
touches, and the privacy checklist every slice passes before build. Nothing
here is scheduled; it exists so backend work starts from a plan instead of a
blank page.

## Phasing — smallest real slice first

| Phase | Surface | Backend needed | New data collected |
|---|---|---|---|
| S0 — Recap (local) | End-of-year / anytime stats recap, rendered on-device, shareable as an *image* | **None** — derives from local SwiftData via the `PracticeStats` layer | None (image share goes through the iOS share sheet) |
| S1 — Shared exercises | Browse + import community exercises; teachers publish theirs | Auth (Sign in with Apple), profile store, shared-exercise store, report/takedown flow | Apple user id, display name, shared exercise recipes |
| S2 — Stats & leaderboards | Opt-in stats profile, friend/global boards | Stats ingest + aggregation, follow graph (optional at first — global boards need none) | Opted-in derived stats only (ADR 0064 §3) |
| S3 — Recap, social edition | Compare recaps, share natively in-app | Rides S2's data; adds nothing new | None beyond S2 |

S0 is buildable **now**, pre-backend, and validates the recap's appeal before
any account exists. S1 before S2: it serves the teacher persona, it's
read-mostly (cheap, low-abuse), and it forces the auth/deletion plumbing into
existence at the smallest possible scale.

## Resource map (extends ADR 0002's AWS footprint)

- **Auth:** Sign in with Apple → token verification in a Lambda authorizer
  (Cognito optional; for this scale a JWT-verifying Lambda is less moving
  machinery). No passwords, no email store.
- **API:** API Gateway + Lambda (same pattern as the AI proxy). One API, routes
  namespaced per slice (`/exercises`, `/stats`, `/profile`).
- **Store:** DynamoDB single-table to start (profiles, shared exercises,
  stats aggregates). S3 only if/when avatars or recap images are hosted.
- **Moderation:** a `reports` table + an admin-only review route. Shared
  exercises are text + numbers, so moderation is spam/abuse-of-text, not media
  review. Rate-limit publishing (n/day) from day one.
- **Deletion/export:** one Lambda that, given a user id, deletes/emits
  everything keyed to it. Built in S1, *before* scale makes it hard.
- **Cost guardrail:** everything above is pay-per-request; the standing rule
  from the backlog holds — no live host in Release until the proxy exists, and
  the AI phase's pricing/cadence decision (backlog "AI phase") gates any
  per-user recurring cost.

## Data classification (the strategy in one table)

| Class | Examples | Lives | Leaves device? |
|---|---|---|---|
| Practice content | songs, bookmarks, waveforms, loops, markers, journals, notes | SwiftData on-device (+ CloudKit private DB, Phase 4) | **Never** to the social backend |
| Derived stats | loop counts, mastery roll-ups, streaks, minutes, tempo achievements | Computed on-device (`PracticeStats`) | Only with explicit per-surface opt-in (S2) |
| Shared content | published exercise recipes, display name | Social backend | Yes — that's its purpose; revocable |
| Identifiers | Apple user id, device push token (if ever) | Social backend | Yes, minimum viable set |

Rules that follow: journals/notes are unclassified for sharing (they don't
appear in the table's "leaves device" column by design); every new collected
field lands in `PrivacyInfo.xcprivacy` in the same PR; App Store privacy
"nutrition label" updates ship with the slice that changes the answer.

## Per-slice privacy checklist (run before building any S-slice)

1. What fields does this surface *show*? Collect exactly those, nothing else.
2. Where does consent live in the UI, and is "off" the default?
3. What happens on account deletion — enumerate every table touched.
4. What does the privacy manifest + nutrition label gain?
5. Can the feature degrade gracefully with no account? (It must.)
6. Is anything being sent that could reconstruct practice *content* rather
   than practice *numbers*? If yes, stop — ADR 0064 §3.

## Open questions (decide at S1 kickoff, not now)

- Display-name policy (real names vs handles; teachers may want real names).
- Exercise attribution on re-share/fork — provenance display, no payments.
- UK GDPR: age gating / parental consent if under-16s are plausibly users.
- Whether S2 leaderboards launch global-only (no follow graph) to avoid
  building a social graph before there's a community.
