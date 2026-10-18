# ADR 0259 — Family Sharing is off

- **Status:** Accepted — Tomisin's call, 2026-10-18. Built on `pocket-371-family-sharing-off`.
  Still owed, outside the repo: creating both products in App Store Connect with Family Sharing off
  (D3). Neither had been created yet.
- **Date:** 2026-10-18
- **Amends:** ADR 0256 — **D6** (Family Sharing is on for both) is reversed: it is off for both. With
  it go D5's paragraph on family-shared Pay once, the Consequences' "Family Sharing on for both" in
  the App Store Connect list, and the sandbox pass's family-shared purchase. Everything else in 0256
  stands.

## Context

ADR 0256 D6 made both products, the monthly and Pay once, family-shareable. On 2026-10-18 Tomisin
took that back: *"we'll take family sharing off for now"*, and then, to be clear, *"off the table i
mean"*. So this isn't a deferral: Family Sharing stays off unless a new ADR turns it on.

The plan hadn't been released yet, so no player had been told it could be shared.

## Decisions

### D1 — Neither product is family-shareable

The monthly and Pay once are both bought for one Apple Account. Bringing Family Sharing back would
take a new ADR.

### D2 — The app stops mentioning it

- `Configuration/RedMoon.storekit` sets `familyShareable` to `false` on both products, so a local
  StoreKit run matches the App Store.
- The wall's renewal disclosure loses its last sentence, *"Both are shared with your family through
  Family Sharing."* `PlanAccessTests` checks that neither version of the disclosure mentions the
  family.
- `OwnedPurchase.isFamilyShared` is deleted. Nothing read it: access had always ignored ownership
  (0256 D6), and the cancel row read the monthly's renewal straight from the transaction.
- **Kept:** `PlanStore` still reads the monthly's renewal, period end and offer only from a
  transaction whose `ownershipType` is `.purchased`. Now every transaction is `.purchased`, so the
  guard never skips anything. It stays because it says whose subscription the cancel row and *Your
  plan* describe, and that has to stay true however the products are set up.
- A revocation now means a refund and nothing else. The rule that closes the plan on one is
  unchanged.

### D3 — App Store Connect

Create both products with Family Sharing **off**, which is the default. Neither product existed in
App Store Connect on 2026-10-18 (Tomisin), so nothing there has to be undone and the ids in 0256 D1
stand. **Keep it off when they're made:** App Store Connect lets Family Sharing be turned on for a
product later but never turned off, so turning it on even once would make that product shareable
for good. The only way out then would be new product ids (`PlanProduct`).

The sandbox pass loses its family-shared purchase case.

## Consequences

- One purchase opens the plan for one Apple Account. A family that wants it on two accounts buys it
  twice.
- **What Apple allows still points one way.** Off can become on later, but on can never become off.
  That is a fact about the platform, not a plan to revisit this. Reopening it takes a new ADR.
- No schema change and no migration, because nothing about ownership was ever stored.

## Alternatives rejected

- **Keep 0256 D6 (on for both).** Tomisin took it off.
- **Leave `isFamilyShared` in place, in case.** It was a field nothing read. Keeping it would make
  Family Sharing look supported when it isn't.
