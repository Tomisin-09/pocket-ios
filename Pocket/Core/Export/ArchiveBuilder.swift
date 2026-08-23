import Foundation

/// Everything the builder reads, gathered by the caller.
///
/// Explicit arrays rather than a `ModelContext` to fetch from, for two reasons: it keeps the builder
/// free of SwiftData so the mapping rules are unit-testable over plain uninserted models (inserting into
/// a container traps in the XCTest host), and it leaves the caller in charge of *which* rows go in —
/// which is where a future "export this routine only" would attach without touching any of this.
@MainActor
struct ArchiveSource {
    var songs: [Song] = []
    var exercises: [Exercise] = []
    var routines: [Routine] = []
    var journal: [JournalEntry] = []
    var recordings: [Recording] = []
    var runs: [PracticeRun] = []
    var goals: [Goal] = []
    var longTermGoals: [LongTermGoal] = []
    var savedChords: [SavedChord] = []
    var profile: Profile?
}

/// Turns the live store into a `PracticeArchive` (ADR 0181).
///
/// `@MainActor`, because reading a `@Model` is main-actor work and neither a model nor a `ModelContext`
/// is `Sendable`. The value it returns *is* `Sendable`, which is the point: the expensive half of an
/// export — encoding, staging the take files, zipping — then runs off the main actor with nothing but
/// plain values in hand. That is `SongImporter`'s split (`prepare` off-main, `persist` on it) turned
/// around, for a job whose costly end is the writing rather than the reading.
///
/// ### Ordering
///
/// Every collection is sorted, and none of them by chance. Two exports of an unchanged library must
/// produce byte-identical JSON — otherwise a player cannot diff two archives to see what changed, and a
/// test cannot assert on output without sorting it first. Natural orders are used where the app already
/// has one (a loop's position in the song, a block's place in a routine) and `uid` breaks every tie.
@MainActor
enum ArchiveBuilder {

    /// Build the archive.
    ///
    /// - Parameters:
    ///   - includesTakeAudio: recorded in the archive so a reader can tell a deliberate omission from a
    ///     lost directory. It does **not** filter `takes`: an archive without audio still carries every
    ///     take's note, its moments and the name of the file it came from.
    static func snapshot(from source: ArchiveSource,
                         appVersion: String,
                         includesTakeAudio: Bool,
                         exportedAt: Date = .now) -> PracticeArchive {
        PracticeArchive(
            exportedAt: exportedAt,
            appVersion: appVersion,
            includesTakeAudio: includesTakeAudio,
            songs: source.songs
                .sorted { ($0.title, $0.sourceID) < ($1.title, $1.sourceID) }
                .map(songRecord),
            exercises: source.exercises
                .sorted { ($0.name, $0.uid.uuidString) < ($1.name, $1.uid.uuidString) }
                .map(exerciseRecord),
            savedChords: source.savedChords
                .sorted { ($0.name, $0.uid.uuidString) < ($1.name, $1.uid.uuidString) }
                .map(savedChordRecord),
            routines: source.routines
                .sorted { ($0.name, $0.uid.uuidString) < ($1.name, $1.uid.uuidString) }
                .map(routineRecord),
            goals: source.goals
                .sorted { ($0.dateAdded, $0.uid.uuidString) < ($1.dateAdded, $1.uid.uuidString) }
                .map(goalRecord),
            longTermGoals: source.longTermGoals
                .sorted { ($0.order, $0.uid.uuidString) < ($1.order, $1.uid.uuidString) }
                .map(longTermGoalRecord),
            practiceRuns: source.runs
                .sorted { ($1.startedAt, $0.uid.uuidString) < ($0.startedAt, $1.uid.uuidString) }
                .map(\.record),
            journal: source.journal
                .sorted { ($1.createdAt, $0.uid.uuidString) < ($0.createdAt, $1.uid.uuidString) }
                .map(journalRecord),
            takes: source.recordings
                .sorted { ($1.createdAt, $0.uid.uuidString) < ($0.createdAt, $1.uid.uuidString) }
                .map(recordingRecord),
            profile: source.profile.map(profileRecord)
        )
    }

    /// ISO-8601 **including fractional seconds**.
    ///
    /// Foundation's built-in `.iso8601` strategy truncates to the second, which silently moves every
    /// date in the archive by up to a second on the way back in — caught by the round-trip test, which
    /// failed against two values that printed identically. A backup that cannot reproduce its own
    /// timestamps is not one, so the format carries milliseconds.
    ///
    /// `Date.ISO8601FormatStyle` rather than `ISO8601DateFormatter`: it is a `Sendable` value type, and
    /// the strategy closures below are `@Sendable` under Swift 6 — capturing a class-based formatter in
    /// one compiles locally and fails on CI's stricter toolchain.
    nonisolated static var dateStyle: Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    }

    /// Encode an archive. `nonisolated` — it touches no model and no actor state, so it runs wherever
    /// the caller is, which for an export of any size should not be the main thread.
    ///
    /// Sorted keys and readable dates, both so the output is stable and legible: a person opening
    /// `practice.json` gets dates they can read rather than seconds since 2001, and a diff between two
    /// archives shows what changed rather than what the encoder felt like ordering differently.
    nonisolated static func encode(_ archive: PracticeArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(dateStyle))
        }
        return try encoder.encode(archive)
    }

    /// Read an archive back. Nothing in the app calls this yet — an importer is out of scope for 0181
    /// — but the encoder above is only trustworthy if something proves it round-trips, and the tests
    /// use this to do it.
    ///
    /// Falls back to whole-second ISO-8601 so a hand-edited file, or one written before fractional
    /// seconds were carried, still parses rather than failing the whole archive over a timestamp.
    nonisolated static func decode(_ data: Data) throws -> PracticeArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(text, strategy: dateStyle) { return date }
            return try Date(text, strategy: Date.ISO8601FormatStyle())
        }
        return try decoder.decode(PracticeArchive.self, from: data)
    }

    // MARK: - Songs

    static func songRecord(_ song: Song) -> SongRecord {
        SongRecord(
            sourceID: song.sourceID,
            sourceRaw: song.sourceRaw,
            title: song.title,
            artist: song.artist,
            album: song.album,
            genre: song.genre,
            year: song.year,
            key: song.key,
            comment: song.comment,
            collections: song.collections.sorted(),
            bpm: song.bpm,
            preciseBPM: song.preciseBPM,
            downbeatSeconds: song.downbeatSeconds,
            extraDownbeatSeconds: song.extraDownbeatSeconds.sorted(),
            beatsPerBar: song.beatsPerBar,
            noteValue: song.noteValue,
            showsGridlines: song.showsGridlines,
            duration: song.duration,
            dateAdded: song.dateAdded,
            lastPracticed: song.lastPracticed,
            lastPracticedSpeed: song.lastPracticedSpeed,
            audioFileName: song.audioFileName,
            // `loopsByStart` and `markersByTime` are the app's own orders — the sequence a player sees
            // them in. `uid` breaks a tie between two loops starting at the same point.
            loops: song.loops
                .sorted { ($0.start, $0.uid.uuidString) < ($1.start, $1.uid.uuidString) }
                .map(loopRecord),
            markers: song.markers
                .sorted { ($0.seconds, $0.uid.uuidString) < ($1.seconds, $1.uid.uuidString) }
                .map { MarkerRecord(uid: $0.uid, seconds: $0.seconds, label: $0.label) },
            references: referenceRecords(song.references)
        )
    }

    static func loopRecord(_ loop: Loop) -> LoopRecord {
        LoopRecord(
            uid: loop.uid,
            name: loop.name,
            start: loop.start,
            end: loop.end,
            speed: loop.speed,
            repeats: loop.repeats,
            loopTypeRaw: loop.loopTypeRaw,
            tags: loop.tags.sorted(),
            isFavorite: loop.isFavorite,
            isBackingTrack: loop.isBackingTrack,
            lastPracticedSpeed: loop.lastPracticedSpeed,
            mastery: loop.mastery,
            masteryAtSpeed: loop.masteryAtSpeed,
            focus: loop.focus,
            commandTempo: loop.commandTempo,
            targetSpeedOverride: loop.targetSpeedOverride,
            automatorEnabled: loop.automatorEnabled,
            automatorTargetSpeed: loop.automatorTargetSpeed,
            automatorStepCount: loop.automatorStepCount,
            automatorLoopsPerStep: loop.automatorLoopsPerStep,
            rampWarmupSteps: loop.rampWarmupSteps,
            rampReachSteps: loop.rampReachSteps,
            rampBackoffSteps: loop.rampBackoffSteps,
            rampRepsPerStep: loop.rampRepsPerStep,
            rampDwellIntervals: loop.rampDwellIntervals,
            includeBackoff: loop.includeBackoff,
            backoffSpeedOverride: loop.backoffSpeedOverride,
            colorIndex: loop.colorIndex,
            customColorHex: loop.customColorHex,
            references: referenceRecords(loop.references)
        )
    }

    /// Links in their authored order (ADR 0167), `uid` breaking a tie.
    static func referenceRecords(_ links: [ReferenceLink]) -> [ReferenceLinkRecord] {
        links
            .sorted { ($0.order, $0.uid.uuidString) < ($1.order, $1.uid.uuidString) }
            .map {
                ReferenceLinkRecord(uid: $0.uid,
                                    title: $0.title,
                                    note: $0.note,
                                    urlString: $0.urlString,
                                    order: $0.order,
                                    dateAdded: $0.dateAdded,
                                    kindRaw: $0.kindRaw)
            }
    }
}
