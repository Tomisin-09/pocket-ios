# 0002 — AI planner runs through a backend proxy; local dev + tiny AWS prod

- **Status:** Accepted
- **Date:** 2026-06-15

## Context

The practice planner uses the Claude API to propose session blocks from loop
history and last-practiced dates. The API key must never ship in the client. The
project will be hosted on AWS, but the team also wants test environments that
are more accessible than a hardened prod, and is open to hosting some interfaces
outside AWS during development.

Separately, most of Pocket needs no server at all: solo data is SwiftData +
CloudKit (Apple's iCloud), and the AWS collaboration layer is parked.

## Decision

- The only V1 server component is a **thin proxy** that holds the Claude API key
  and forwards planner requests. It authenticates callers with the
  Sign-in-with-Apple identity token and rate-limits per user.
- The app chooses its backend **base URL by build configuration**:
  - **Debug** → a local or non-AWS dev proxy (e.g. a local server / Cloudflare
    Worker / Vercel) — fast to iterate, fully accessible for debugging.
  - **Release** → a small **AWS** prod stage (Lambda + API Gateway), defined in
    Terraform under `infrastructure/`.
- The planner has a **deterministic local fallback** so the home screen works
  offline and without the proxy (it "proposes, doesn't prescribe" — that should
  hold without a network too).

## Consequences

- No AWS footprint is required for Phases 1–3; the proxy and its Terraform land
  in Phase 4.
- Practice history is sent off-device only when the AI planner is used. It must
  be **opt-in** and declared in `PrivacyInfo.xcprivacy` and the privacy policy
  before Phase 4 ships.
- Keeping prod tiny avoids over-building the parked collaboration architecture.

## Alternatives considered

- **All-AWS dev + prod stages** — rejected for early dev: less locally
  accessible and more infra to stand up before it earns its keep. Can be adopted
  later if a shared dev environment is needed.
- **No backend, call Claude from the client** — rejected: would leak the API key.