import Foundation

/// Names for a duplicated unit — "Spider" → "Spider copy" → "Spider copy 2" (Slice 3).
///
/// Pure and Foundation-only so the naming rule is unit-tested rather than re-derived at each call
/// site, matching `QuickSessionNaming`.
enum CopyNaming {
    /// The name a duplicate of `name` should take, avoiding any name already in `existing`
    /// (compared case- and whitespace-insensitively, as the user reads them).
    ///
    /// Duplicating a duplicate re-uses the **stem**, so a third copy of "Spider" reads
    /// "Spider copy 2" rather than "Spider copy copy".
    static func copyName(of name: String, existing: [String]) -> String {
        let stemmed = stem(of: name)
        let base = stemmed.isEmpty ? "Untitled" : stemmed
        let taken = Set(existing.map(normalized))
        let first = "\(base) copy"
        guard taken.contains(normalized(first)) else { return first }
        var counter = 2
        while taken.contains(normalized("\(base) copy \(counter)")) { counter += 1 }
        return "\(base) copy \(counter)"
    }

    /// The original name behind a generated copy name: "Spider copy 3" and "Spider copy" both
    /// stem to "Spider". Deliberately narrow — it only strips the exact `" copy"`/`" copy N"`
    /// marker this generator produces, so "Exercise 2" and "Copy of the master" are untouched.
    static func stem(of name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        var candidate = trimmed
        // A trailing counter only counts when it sits on a " copy" — otherwise "Exercise 2" would
        // lose its 2 and duplicate as "Exercise copy".
        if let lastSpace = candidate.lastIndex(of: " "),
           Int(candidate[candidate.index(after: lastSpace)...]) != nil {
            let withoutCounter = String(candidate[..<lastSpace]).trimmingCharacters(in: .whitespaces)
            if withoutCounter.lowercased().hasSuffix(" copy") { candidate = withoutCounter }
        }
        guard candidate.lowercased().hasSuffix(" copy") else { return trimmed }
        return String(candidate.dropLast(" copy".count)).trimmingCharacters(in: .whitespaces)
    }

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased()
    }
}

extension Exercise {
    /// A duplicate of this drill under `name` — the same **shape**, none of the **history**
    /// (Slice 3).
    ///
    /// Carried: the template, instrument and authored content payload, the meter/accents/
    /// subdivision, every tempo (working, command, both overrides), the whole ramp recipe, tags and
    /// notes. In other words everything you'd have re-typed to build the same drill.
    ///
    /// Deliberately **not** carried:
    /// - `mastery` / `lastPracticed` — a copy is unrated and unpractised; inheriting a self-rating
    ///   for playing you haven't done would put a made-up number into the planner's dueness (ADR
    ///   0070: the app never invents a proficiency figure).
    /// - `isFavorite` — the pin is about *this* row, not the shape.
    /// - `presetSlug` — provenance is where a drill *came from*. A copy is user-authored, so it
    ///   loses the seeded-preset marker along with its free-taste **run** allowance (ADR 0112).
    ///   That closes the obvious bypass — duplicating a freebie can't mint an unlocked Pro drill.
    /// - `journal` / `recordings` — takes and dated entries belong to the sessions that made them.
    ///
    /// `linkedSongs` is a relationship, so it can't be set before insertion: assign it from the
    /// caller after `context.insert` (a copy is *for* the same repertoire, ADR 0111).
    func duplicated(named name: String) -> Exercise {
        let copy = Exercise(name: name,
                            currentTempo: currentTempo,
                            commandTempo: commandTempo,
                            targetTempo: targetTempo,
                            beatsPerBar: beatsPerBar,
                            noteValue: noteValue,
                            accentBeats: accentBeats,
                            subdivision: subdivision,
                            template: template,
                            instrument: instrument,
                            templatePayload: templatePayload,
                            rampStepBPM: rampStepBPM,
                            rampIntervalCount: rampIntervalCount,
                            rampIntervalUnit: rampIntervalUnit,
                            dwellIntervals: dwellIntervals,
                            includeBackoff: includeBackoff,
                            rampReachSteps: rampReachSteps,
                            rampBackoffSteps: rampBackoffSteps,
                            backoffTempoOverride: backoffTempoOverride,
                            tags: tags,
                            notes: notes)
        copy.targetTempoOverride = targetTempoOverride
        return copy
    }
}

extension Routine {
    /// A duplicate of this routine under `name`, plus its blocks cloned in play order and
    /// **renumbered** from 0 (so a routine whose `order` values have drifted copies clean).
    ///
    /// Both are returned **uninserted** and are assembled by the caller — a `RoutineItem` is a
    /// `@Model` in its own right, so the parent has to be inserted before its blocks are attached.
    ///
    /// `lastPracticed`, `isFavorite` and `presetSlug` are not carried, for the same reasons as
    /// `Exercise.duplicated(named:)`: a copy has no history of its own, and a copy of the curated
    /// free-taste routine is a user-authored routine, not a second freebie (ADR 0112).
    func duplicated(named name: String) -> (routine: Routine, blocks: [RoutineItem]) {
        let blocks = orderedItems.enumerated().map { RoutineItem.copying($1, order: $0) }
        return (Routine(name: name), blocks)
    }
}

extension RoutineItem {
    /// A clone of `item` at `order` — same kind, reps and loop run mode, pointing at the **same**
    /// unit. The units themselves are shared, not copied: a routine references its exercises and
    /// loops (`.nullify`, ADR 0066 R4/R5), so duplicating the session must not fork the library.
    static func copying(_ item: RoutineItem, order: Int) -> RoutineItem {
        let copy = RoutineItem(kind: item.kind, order: order)
        copy.reps = item.reps
        copy.loopRunModeRaw = item.loopRunModeRaw
        copy.exercise = item.exercise
        copy.loop = item.loop
        copy.song = item.song
        return copy
    }
}
