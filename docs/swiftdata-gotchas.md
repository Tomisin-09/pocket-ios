# SwiftData gotchas — a pre-flight checklist

SwiftData has bitten this project four separate times, and **most of these only
reproduce on device** — the in-memory test store and the simulator hide them.
Run this checklist whenever you touch a `@Model`, a `#Predicate`, or a
`.sheet`/navigation driven by a model. Each item links to the ADR that paid the
tuition.

## When you change a `@Model`

- [ ] **Never store a custom `enum` (or other non-primitive) as a stored
      attribute.** Back it with a primitive (`String`/`Int`) + a computed
      accessor that maps to the enum. Storing the enum directly crashes on
      **migration** on a device that has old data — the in-memory test store
      starts empty, so tests pass and the device traps.
      → [ADR 0011](decisions/0011-persistence-swiftdata.md),
      memory `swiftdata-enum-attr-migration-crash`
- [ ] **Device-test every model change** with *existing* data (build over an
      install that already has songs/loops), not a clean install. Migration
      crashes are invisible to a fresh launch.
- [ ] If you add/rename/retype a stored property, note whether it's a **lossy**
      migration and say so in the ADR (see the field-model audit, ADR 0036).

## When you write a `#Predicate` / `@Query`

- [ ] **No optional comparisons in a `#Predicate`** (`x.foo == nil`,
      `x.foo != nil`, or reaching through an optional relationship). SwiftData
      compiles it to SQL that **starves the main thread** and freezes the UI.
      Fetch the broader set and filter in memory instead.
      → memory `swiftdata-optional-predicate-freeze`
- [ ] Keep predicates over indexed primitive columns; do derived/optional
      filtering in Swift after the fetch.

## When a sheet / navigation is driven by a model

- [ ] **Don't present with `.sheet(item:)` keyed on a freshly-inserted model's
      `persistentModelID`.** On first save the ID flips from temporary to
      permanent, SwiftUI sees the identity change, and the sheet **dismisses
      itself mid-edit**. Only session-new models hit this.
      Present by a stable `uid` via a `StableRef` wrapper instead.
      → [ADR 0090](decisions/0090-present-model-sheets-by-stable-uid.md),
      memory `swiftdata-sheet-item-persistentid-dismiss`

## When you write tests around models

- [ ] **Don't `context.insert(...)` a full sample object graph in a test** — it
      `SIGTRAP`s in the XCTest host. For property/logic tests, construct the
      `@Model` object **uninserted** and assert on its properties directly.
      → memory `swiftdata-insert-test-host-trap`
- [ ] Remember tests run against an **in-memory** store: they will **not** catch
      migration crashes, main-thread predicate freezes, or the sheet-dismiss
      identity flip. Those are device-only. Green tests ≠ safe model change.

## Debugging discipline (learned the hard way)

- [ ] Before blaming a model change for a "freeze/regression," **rule out the
      environment**: check Mac uptime/swap and re-run on a freshly-erased sim. A
      thrashing machine masqueraded as a run-screen freeze once and a feature got
      wrongly parked.
      → memory `ui-test-isolation-confound-cold-sim`,
      `fix-stuck-xcode-device-connection`
- [ ] Read the actual `.ips` crash report before theorizing about SwiftData
      traps — the stack frame names the culprit.

---
*Keep this in sync with the ADRs above. When SwiftData bites in a new way, add a
line here first, then write the ADR.*
