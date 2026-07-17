# 0092 — AI strategy: boundaries, guardrails, and the foundations it must land on

- **Status:** Proposed (2026-07-13)
- **Date:** 2026-07-13

## Context

Pocket's AI direction has until now lived implicitly across several documents —
the proxy architecture (ADR 0002), the no-grading rule (ADR 0070), the backlog's
"AI is a late phase" sequencing, the local planner's "AI suggester deferred"
posture (ADR 0072/0073), and the privacy walls around audio (ADR 0001/0064/0069).
As value-add features accumulate (recording, tab translation, profiles) each one
now tends to reach for AI, so the team needs a single place that states what AI
is *for*, what it must never do, and the readiness bar it has to clear before the
first feature ships. This ADR consolidates those scattered decisions and adds an
explicit prerequisites list; it does not by itself schedule any AI feature.

**Plain-terms framing (kept deliberately, because it is the point):** AI is a
knowledgeable *practice buddy* the user can opt into — not the teacher and not the
app. It only ever **suggests and creates**; the app works fully without it; the
user's audio never leaves the device; and the secret that talks to the model lives
on our server, never in the client.

## Decision

### A. Boundaries — what AI is, and what it must never be

1. **AI never grades the player (restates ADR 0070 as an AI guardrail).** No
   scoring, no pitch/timing detection, no pass/fail, no analysis of a recording
   for correctness. This rules out the entire "AI coach that listens and corrects
   you" category. AI helps the user *decide what to practice* and *author their
   own material*; the player stays the judge. This is enforced at the model
   boundary (§B4), not left to prompt wording alone.

2. **AI is a late, additive layer — never a foundation.** Every AI feature ships
   only after its local, deterministic version is solid, and every AI feature has
   a **deterministic local fallback** (ADR 0002). The app must be fully useful
   offline, with no account and no AI. AI augments; it never gates core function.

3. **The key never ships in the client; AI runs through the proxy (ADR 0002).**
   The Claude API key lives only in the backend proxy, which authenticates callers
   with the Sign-in-with-Apple identity token and rate-limits per user. The AI
   phase is therefore the event that introduces Sign in with Apple — identity is
   added once, here, and profiles/entitlement/social attribution all hang off it.

4. **Audio never goes to the proxy.** The rights/privacy walls (ADR 0001/0064/0069)
   hold: recordings and app playback are never sent to a model. Any future change
   to this is its own ADR against this clause, not a drift.

5. **Generation is in-house, never from a scraped catalog.** AI generates from our
   own theory substrate (chords/scales/tunings — ADR 0084/0085) plus the user's own
   inputs. It never draws on, or reconstitutes, a copyrighted content library —
   same discipline as the guitargearfinder stance (encode methods, not content).

6. **AI is opt-in and data-flow-honest.** Practice context leaves the device only
   when an AI feature is used, only with explicit opt-in, and only as declared in
   `PrivacyInfo.xcprivacy` and the privacy policy. What is sent is the minimum the
   feature needs (§B2), and the backend does not retain prompt content.

### B. Foundations — the readiness bar before the first suggester ships

The substrate AI reasons over **already exists** because Pocket was built
local-first: structured practice signals (`mastery`, `lastPracticed`, `dueScore`,
skill taxonomy, goals — ADR 0072/0073), the deterministic planner that is both the
thing AI augments and its fallback, the theory substrate, and the journal corpus.
What remains is infrastructure and product scaffolding:

1. **Stand up the backend for real.** Deploy the proxy (Lambda + API Gateway,
   Terraform under `infrastructure/`), add **Sign-in-with-Apple identity + token
   validation**, **per-user rate-limiting + quota**, and **cost/latency
   observability**. Inference is the real metered cost; it is not run blind.

2. **Send a curated context, not raw models.** A minimal, structured **context
   DTO** carries only what a feature needs — never a serialized SwiftData graph.
   This serves privacy (data minimization), cost (fewer tokens), and quality
   (focused context) at once.

3. **Structured-output contract.** The model returns a **schema-valid app object**
   (`Routine`/`Exercise`/`Loop`) via tool-use / structured output, never prose to
   be parsed. The guardrails — the §A1 no-grading line and "stay within the app's
   vocabulary" — are enforced in this contract. This is what makes suggestions
   land instead of erroring.

4. **Evaluation + prompt discipline.** A small eval set of real scenarios
   (goal → a reasonable session) exists before shipping, so prompts can be iterated
   and rolled back safely; prompts are versioned. Cost is controlled with **prompt
   caching** and **model tiering** (a cheap/fast model for classification, a
   stronger one for planning).

5. **Product + trust scaffolding.**
   - **"Proposes, doesn't prescribe" as a UX invariant** — AI output is always
     editable and rejectable, never auto-applied. This is the same authority the
     no-grading rule protects: the user decides.
   - **One bounded, named AI surface** rather than AI sprinkled through the app —
     a legible "room" the user can reason about. Working name **"Red Moon Oracle"**;
     it is a candidate home for the parked blood-moon theme (Slice 2 of the home
     re-theme, ADR 0081), though that theme stays parked and is not a dependency.
   - **Complete states** — loading/streaming, error, rate-limited, and empty
     (inference takes seconds; streaming softens the wait).
   - **Consent + compliance** — a Settings opt-in, a first-use explainer of what
     leaves the device, `PrivacyInfo.xcprivacy`, the privacy-policy page, a
     no-retention backend posture, and the SIWA-mandated in-app account deletion.
     The `/ready-to-ship` gate covers the submission surface.

6. **A settled pricing/cadence model (non-technical prerequisite).** Because each
   call costs real money, the free/paid boundary is decided before the switch is
   flipped. AI — not storage — is the paid-tier lever (see ADR 0069 discussion:
   storage is near-free; inference is the usage-correlated cost).

### C. Candidate surfaces (illustrative, not a schedule)

Consistent with §A, all first-wave uses augment *planning* or *authoring*:
planner decomposition / goal→blocks (the anchor use, ADR 0002); freeform ASCII
tab → loop/exercise (structured `.gp`/MusicXML stays deterministic-local);
practice-note / journal summarization (over text + metadata, never audio);
suggested automator / exercise settings. None grades the player; none touches
audio content.

## Consequences

- **AI has one written charter.** The no-grading and audio-never-to-proxy lines
  are now explicit guardrails a new feature is measured against, not inferences
  from five documents.
- **The first AI feature carries a real infrastructure + compliance cost** — the
  backend, SIWA, privacy manifest/policy, and account deletion — batched into the
  AI phase rather than paid piecemeal.
- **The highest-leverage foundations are §B3 + §B4** (structured output + eval):
  they are the difference between reliably valid, good practice plans and
  occasional garbage the app can't use, and they are the part most easily skipped.
- **Identity is introduced exactly once, here**, and the profiles/social/
  entitlement work hangs off it (reconciles with ADR 0002 and the profiles
  discussion).
- **A "record with AI feedback on your playing" request is a new ADR against §A1**,
  not a drift — the same discipline ADR 0001/0064/0069/0070 hold elsewhere.

## Alternatives considered

- **AI-first / AI as a core dependency** — rejected (§A2): breaks the offline,
  no-account, local-first guarantee and removes the deterministic fallback.
- **On-device / client-side model calls** — rejected (§A3): would leak the key and
  forgo per-user metering; also less controllable for cost and prompt iteration.
- **AI that evaluates the player's performance** — rejected (§A1): contradicts
  ADR 0070 and the product's core "the player is the judge" stance.
- **Sending audio to the model for transcription/feedback** — rejected for now
  (§A4): reopens the rights/privacy walls; reconsidered only via a dedicated ADR.
- **Prose responses parsed heuristically** — rejected (§B3): unreliable and
  costly; structured output is a hard requirement.
