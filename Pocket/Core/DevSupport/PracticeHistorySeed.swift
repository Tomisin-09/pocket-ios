#if DEBUG
import Foundation
import SwiftData

/// DEBUG-only **earned state** for the user-manual shoot (ADR 0165, Phase 5).
///
/// `ScreenshotSeed` builds a library — songs, waveforms, loops. What it cannot build is anything the
/// app only ever writes *while someone is using it*. `PracticeRun`, `JournalEntry` and `Recording`
/// rows come from `PracticeLogWriter` and `JournalWriter` as a player finishes things; a `SavedChord`
/// comes from the custom placer when a player keeps a voicing. None of them exist on a freshly
/// seeded install, so Progress opens on an empty chart, the Journal on an empty timeline, and the
/// Toolkit on *My chords, none saved*. Nine of the manual's ninety-six figures are of exactly those
/// screens, which is why they were the only ones the walk could not drive and were about to be shot
/// by hand on a real phone instead.
///
/// Shooting them by hand works, but it costs the manual its consistency: a hand-shot Progress screen
/// shows whatever songs the photographer actually practises, while every other figure in the book
/// shows the seeded library. This closes that gap by writing the same shapes the app writes.
///
/// Runs **only** under `-seedHistory` and only into a store with no runs in it, so a normal launch
/// and a re-launch are both untouched. Kept separate from `-seedScreenshots` deliberately: the App
/// Store shoot uses that flag and wants a clean, ahistorical library.
///
/// Everything here is deterministic — fixed offsets from today, no RNG — so two runs of the shoot
/// produce identical figures and a reshoot of one page doesn't disagree with the page beside it.
enum PracticeHistorySeed {

    static let launchArgument = "-seedHistory"

    /// Which of the last six weeks were practised, as whole days back from today.
    ///
    /// Chosen rather than generated, to satisfy three markers at once: `journal/progress` wants
    /// "several weeks", `journal/month-heatmap` wants "two or more weeks of history in the current
    /// month", and the `This week` bar chart wants a week that isn't one lonely bar. Five of the last
    /// seven days appear here, and the span reaches back far enough that the heatmap has shape.
    ///
    /// ⚠️ The month requirement is the one thing a table of offsets cannot guarantee: shoot on the
    /// 3rd and the current month holds three days no matter what this says. Shoot past mid-month.
    private static let practisedDayOffsets = [
        0, 1, 3, 4, 6, 7, 9, 10, 11, 13, 14, 16, 17, 19,
        21, 22, 24, 25, 27, 29, 30, 32, 34, 35, 37, 39, 40, 41
    ]

    /// Minutes practised on a day, indexed by that day's position in `practisedDayOffsets`.
    ///
    /// Deliberately uneven and deliberately *small*. A heatmap where every cell is the same shade
    /// shows nothing, and a manual that opens on a 90-minute practice day sets an expectation the
    /// app exists to argue against (ADR 0070 — it never grades, and neither does its manual).
    private static let minutesByDay = [
        17, 9, 22, 12, 8, 26, 14, 11, 19, 7, 23, 15, 10, 18,
        13, 21, 9, 16, 24, 12, 8, 20, 11, 25, 14, 9, 17, 13
    ]

    /// Tempos for the exercise runs, in BPM, walked upward across the six weeks so the month's
    /// `new tempos` figure is non-zero and the trajectory reads as a trajectory.
    private static let exerciseTempos = [72, 76, 80, 84, 88, 92, 96, 100]

    // MARK: - Entry point

    /// Write a practice history if launched with `-seedHistory` and there is none.
    ///
    /// Must run **after** `ScreenshotSeed`: journal entries and takes hang off the seeded loops and
    /// exercises, and without them the entries would render as orphans — a legitimate state
    /// (`JournalEntryOwnerKind.orphan`), but not the one any of these seven figures is of.
    @MainActor
    static func seedIfNeeded(into context: ModelContext) {
        guard CommandLine.arguments.contains(launchArgument) else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<PracticeRun>())) ?? 0
        guard existing == 0 else { return }

        let loops = (try? context.fetch(FetchDescriptor<Loop>())) ?? []
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []

        seedRuns(loops: loops, exercises: exercises, into: context)
        seedJournal(loops: loops, exercises: exercises, into: context)
        seedTake(loops: loops, into: context)
        seedRecency(into: context)
        seedSavedChords(into: context)

        try? context.save()
    }

    // MARK: - The chords behind My chords

    /// Four voicings in the Toolkit's chord library.
    ///
    /// Real shapes, spelled correctly, because a manual figure is a diagram someone will put their
    /// fingers on — a plausible-looking invented grid would teach a wrong chord from a page whose
    /// whole claim is that it matches the app. Written high-e first (index 0) through low-E, the
    /// `ChordVoicing` convention: `nil` muted, `0` open, `n` fretted at absolute fret `n`.
    ///
    /// Chosen to be the kind of thing a player *saves* rather than looks up — an alternate fingering,
    /// a partial shape — since `SavedChord` exists for voicings built in the custom placer (ADR 0095)
    /// and a grid of open C, G and D would misrepresent what the screen is for.
    private static let savedVoicings = [
        ChordVoicing("Fmaj7 (no barre)", frets: [0, 1, 2, 3, nil, nil],
                     fingers: [nil, 1, 2, 3, nil, nil]),
        ChordVoicing("Cadd9", frets: [3, 3, 0, 2, 3, nil], fingers: [3, 4, nil, 1, 2, nil]),
        ChordVoicing("Dsus4", frets: [3, 3, 2, 0, nil, nil], fingers: [4, 3, 1, nil, nil, nil]),
        ChordVoicing("Em7", frets: [0, 3, 0, 2, 2, 0], fingers: [nil, 3, nil, 1, 2, nil])
    ]

    /// Write the saved chords, newest last so the grid's "newest first" order is the array reversed
    /// — which is what makes the figure stable rather than dependent on how fast the loop ran.
    ///
    /// Guarded on its own count, not on the run count that gates the rest of this seed: the two are
    /// independent records and a store could plausibly hold one without the other.
    @MainActor
    private static func seedSavedChords(into context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<SavedChord>())) ?? 0
        guard existing == 0 else { return }

        for (index, voicing) in savedVoicings.enumerated() {
            let chord = SavedChord(voicing)
            // Distinct, descending timestamps: `createdAt` is the sort key, and four chords written
            // in the same millisecond order themselves arbitrarily from one run to the next.
            chord.createdAt = calendarDay(daysAgo: savedVoicings.count - index) ?? .now
            context.insert(chord)
        }
    }

    /// Stamp `lastPracticed` on the songs and routines, so Home has a past too.
    ///
    /// Found the hard way: seeding the practice log alone left `Jump back in` absent from Home, and
    /// the capture still passed, because it asserted it was *on* Home rather than that Home was in
    /// the state the figure needs. `HomeFeed.mostRecentlyPracticed` reads `Song.lastPracticed`, not
    /// the log — they are two independent records of the same fact, and only one of them is what
    /// Home reads. `reference/home` is specified as "one song recently practised", which is this
    /// field and not a `PracticeRun` row.
    @MainActor
    private static func seedRecency(into context: ModelContext) {
        let songs = (try? context.fetch(FetchDescriptor<Song>())) ?? []
        // Newest first by index, so the resume card is stable across runs rather than whichever
        // song the fetch happened to return first.
        for (index, song) in songs.enumerated() {
            song.lastPracticed = calendarDay(daysAgo: index)
            song.lastPracticedSpeed = index == 0 ? 0.75 : nil
        }

        let routines = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        for (index, routine) in routines.enumerated() {
            routine.lastPracticed = calendarDay(daysAgo: index + 1)
        }
    }

    // MARK: - The log behind Progress

    /// One to three runs per practised day, alternating unit kinds so the log isn't a single colour.
    ///
    /// Goes through `PracticeRun` directly rather than `PracticeLogWriter`: the writer saves on every
    /// insert and defaults `endedAt` to now, and this is writing eighty-odd rows into the past.
    /// The row shape is the writer's, field for field — see `PracticeLogWriter.log`.
    @MainActor
    private static func seedRuns(loops: [Loop], exercises: [Exercise], into context: ModelContext) {
        let midday = 14

        for (index, dayOffset) in practisedDayOffsets.enumerated() {
            guard let day = calendarDay(daysAgo: dayOffset) else { continue }
            let totalMinutes = minutesByDay[index % minutesByDay.count]

            // Split the day's minutes across one or two runs, so `All-time` counts sessions at a
            // believable rate against its minutes rather than one run per day exactly.
            let splits: [Int] = totalMinutes >= 18
                ? [totalMinutes * 2 / 3, totalMinutes / 3]
                : [totalMinutes]

            for (slot, minutes) in splits.enumerated() where minutes > 0 {
                let startedAt = Calendar.current.date(
                    byAdding: .minute, value: slot * 40,
                    to: Calendar.current.date(byAdding: .hour, value: midday, to: day) ?? day
                ) ?? day

                let run = makeRun(index: index + slot,
                                  startedAt: startedAt,
                                  minutes: minutes,
                                  loops: loops,
                                  exercises: exercises)
                context.insert(run)
            }
        }
    }

    /// One row, with the unit kind and tempo chosen from the row's position so the mix is stable.
    @MainActor
    private static func makeRun(index: Int,
                                startedAt: Date,
                                minutes: Int,
                                loops: [Loop],
                                exercises: [Exercise]) -> PracticeRun {
        let seconds = Double(minutes * 60)

        // Three runs in four are on a unit; the fourth is a play-along, which carries minutes and a
        // day but no tempo (ADR 0071) and keeps the log from reading as all drill.
        switch index % 4 {
        case 0, 2:
            let exercise = exercises.isEmpty ? nil : exercises[index % exercises.count]
            return PracticeRun(startedAt: startedAt,
                               durationSeconds: seconds,
                               kind: .exercise,
                               unitUID: exercise?.uid,
                               tempoBPM: exerciseTempos[index % exerciseTempos.count],
                               notesPerBeat: 2)
        case 1:
            let loop = loops.isEmpty ? nil : loops[index % loops.count]
            return PracticeRun(startedAt: startedAt,
                               durationSeconds: seconds,
                               kind: .loop,
                               unitUID: loop?.uid,
                               tempoPercent: 75 + (index % 4) * 5)
        default:
            return PracticeRun(startedAt: startedAt,
                               durationSeconds: seconds,
                               kind: .song,
                               unitUID: nil)
        }
    }

    // MARK: - The timeline behind Journal

    /// What the seeded journal says.
    ///
    /// Written as a player writes: specific, about the playing, and never a verdict on it. Two are
    /// attached to a loop (so they carry mastery dots and a command tempo), two to an exercise (so
    /// they carry a BPM), and they land across two adjacent days because both journal markers ask
    /// for "notes and a take across two days".
    private static let loopNotes = [
        (text: "Cleaner through the turnaround once I stopped rushing the last two beats.",
         kind: EntryKind.breakthrough, mastery: 3, tempo: 0.75),
        (text: "The bend still lands flat when I take it above three quarters speed.",
         kind: EntryKind.struggle, mastery: 2, tempo: 0.85)
    ]

    private static let exerciseNotes = [
        (text: "Keep the picking hand quiet before pushing this any faster.",
         kind: EntryKind.goal, bpm: 92),
        (text: "Sat at this tempo all week and it finally feels unhurried.",
         kind: EntryKind.note, bpm: 84)
    ]

    @MainActor
    private static func seedJournal(loops: [Loop], exercises: [Exercise], into context: ModelContext) {
        // Yesterday and the day before: two day headings, both close enough to the top of the
        // timeline that the shoot doesn't have to scroll to find them.
        for (index, note) in loopNotes.enumerated() {
            guard let day = calendarDay(daysAgo: index + 1),
                  let createdAt = Calendar.current.date(byAdding: .hour, value: 19 - index, to: day)
            else { continue }

            let entry = JournalEntry.forLoop(text: note.text,
                                             kind: note.kind,
                                             masteryAtEntry: note.mastery,
                                             commandTempoAtEntry: note.tempo,
                                             createdAt: createdAt)
            entry.loop = loops.isEmpty ? nil : loops[index % loops.count]
            context.insert(entry)
        }

        for (index, note) in exerciseNotes.enumerated() {
            guard let day = calendarDay(daysAgo: index + 1),
                  let createdAt = Calendar.current.date(byAdding: .hour, value: 11 + index, to: day)
            else { continue }

            let entry = JournalEntry.forExercise(text: note.text,
                                                 kind: note.kind,
                                                 commandBpmAtEntry: note.bpm,
                                                 commandNotesPerBeatAtEntry: 2,
                                                 createdAt: createdAt)
            entry.exercise = exercises.isEmpty ? nil : exercises[index % exercises.count]
            context.insert(entry)
        }
    }

    // MARK: - The take

    /// One recorded take, owned by a loop so the row renders with its owner caption underneath —
    /// which is the whole subject of `journal/take-row`.
    ///
    /// **No audio file is written.** `JournalTakeRow` renders entirely from the model — play button,
    /// title, duration, time, caption — and never consults the disk, so a still of it needs no bytes
    /// behind it. Tapping play on a seeded take will find nothing; that is the one thing this seed
    /// does not reproduce, and it is not in frame.
    @MainActor
    private static func seedTake(loops: [Loop], into context: ModelContext) {
        guard let day = calendarDay(daysAgo: 1),
              let createdAt = Calendar.current.date(byAdding: .hour, value: 19, to: day)
        else { return }

        let uid = UUID()
        let take = Recording(fileName: RecordingStore.fileName(for: uid),
                             duration: 47,
                             uid: uid,
                             createdAt: createdAt,
                             loop: loops.first)
        context.insert(take)
    }

    // MARK: - Dates

    /// Midnight, `daysAgo` days back. Everything here is anchored to the start of a day so a shoot
    /// that runs at 23:55 doesn't quietly drop a run into tomorrow.
    private static func calendarDay(daysAgo: Int) -> Date? {
        let today = Calendar.current.startOfDay(for: .now)
        return Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)
    }
}
#endif
