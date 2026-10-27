# ADR 0277 — The prices App Store Connect sells: £0.99 a month, or £14.99 once

- **Status:** Accepted. Decided with Tomisin on 2026-10-26 while creating the products in App Store
  Connect (release step 5). Built on `pocket-390-release-1-4`.
- **Date:** 2026-10-26
- **Amends:** ADR 0256 — **D1**: the prices become £0.99 a month and £14.99 once, and *"Round on
  purpose"* goes. The monthly's product id becomes `click.decooperations.pocket.plan.monthly2`. The
  rest of D1 stands: the free week, the group named *Red Moon*, the name *Pay once*, no annual plan.
  ADR 0274 — **D2**: *"They stay £1 a month and £15 once"* now reads £0.99 and £14.99. D1's quoted
  first line follows the products' prices, as it always did. The lock and the promise's wording
  stand.
- **Relates to:** 0259 (Family Sharing is off on the new products too) · 0145 D6 (help copy names no
  price) · 0144 (the old group *Red Moon Pro* and its two products)
- **Schema:** none.

## Context

0256 D1 chose round prices, £1 and £15, because a round figure "seems more intentional, no tricks or
nothing". On 2026-10-26, setting the United Kingdom as the base storefront, Tomisin found that App
Store Connect offered no £1.00 or £15.00 price point.

Two other things came up the same day:

- Tomisin's first idea was to make the founding price (0274) an introductory offer on both products.
  That can't work (D2).
- The monthly was first created in the old group, *Red Moon Pro*, by mistake. A subscription can't
  move to another group, and App Store Connect never reuses a product id. So it was deleted and made
  again in a new group, under a new id (D3).

## Decisions

### D1 — £0.99 a month, or £14.99 once

| | Price (UK, the base storefront) | Kind | Product id |
|---|---|---|---|
| Monthly | **£0.99** a month | auto-renewable subscription, group *Red Moon* | `click.decooperations.pocket.plan.monthly2` |
| **Pay once** | **£14.99** | non-consumable | `click.decooperations.pocket.plan.payonce` |

- These are the nearest points App Store Connect offers.
- **Other storefronts** take the prices App Store Connect generates from the UK. That's 0256 D1's
  rule, kept.
- **The app writes whatever price the store sends** (0256 D3). The wall now reads *£0.99 a month, or
  £14.99 once.* No copy changes. `PlanPrice` keeps its whole-amount rule for storefronts whose
  generated price is a whole number.
- 0274 D2's rules are unaffected: no end date, no countdown, no struck-through "usual price".

### D2 — The founding price is the product's price, not an introductory offer

- **Pay once** is a non-consumable. Introductory offers only exist for auto-renewable subscriptions.
- **The monthly** can have one introductory offer per storefront at a time, and that offer is the free
  week (0256 D1).
- **An introductory offer ends.** It lasts a year at most, and each Apple Account can redeem one per
  subscription group. After that the base price applies. 0274's *"for as long as you keep the plan"*
  can't rest on that.
- So the lock stays as 0274 D3 describes it. On the day of a price rise, choose App Store Connect's
  *Keep the current price for existing subscribers*.

### D3 — A new group, *Red Moon*, and a new id for the monthly

- **The monthly lives in a new subscription group, *Red Moon*,** the name 0256 D1 always gave it.
  Players see that name in Settings ▸ Subscriptions.
- ***Red Moon Pro*** (0144's group) keeps its two products, `…pro.monthly` and `…pro.annual`,
  removed from sale. They were approved with 1.1, and approved products can't be deleted, so the
  group stays.
- **`click.decooperations.pocket.plan.monthly` is spent.** It was created in *Red Moon Pro* by
  mistake and deleted. App Store Connect never reuses a product id. **Never put it back in code**:
  the product would fail to load, and the wall would have no monthly to offer.
- **Only the id constant changes.** The app reads the group id from the product and from each
  transaction, never from a constant (`PlanStore`).

## Consequences

- **Code:** `PlanProduct.monthly`, the StoreKit configuration's id and prices, the wall's preview
  prices and three doc comments. No copy change. No test change: the copy tests take a price as
  their input.
- **Docs:** `PROJECT.md`, `docs/architecture.md`, the CHANGELOG's plan entry and
  `docs/app-store-listing-copy.md`.
- **Owed outside the repo:** the site names £0.99 and £14.99 wherever it names a price. The App Store
  description names none (0256's listing rule).
- **Reversibility.** Moving to a round point later, if App Store Connect ever offers one, would be a
  price rise, so 0274 D4 governs it.

## Alternatives rejected

- **The founding price as an introductory offer.** See D2.
- **Keeping the monthly in *Red Moon Pro* and renaming the group.** It would have kept the original
  id. But it would have left the plan next to two dead products for good, under a name players see
  that needed changing anyway.
