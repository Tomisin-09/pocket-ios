import Foundation
import SwiftData

/// The rows an archive already has counterparts for, so a restored row can point at them
/// (ADR 0188 D1).
///
/// A restore into a populated library has to resolve links against **both** what it is adding and
/// what is already there. A routine whose blocks name an exercise the library already holds must
/// point at that exercise — not at a copy, and not at nothing. So every lookup goes through here, and
/// the writer fills it in as it goes.
@MainActor
struct RestoreResolver {
    var songs: [String: Song] = [:]
    var loops: [UUID: Loop] = [:]
    var exercises: [UUID: Exercise] = [:]

    /// Read what the library already has. Fetched whole rather than queried per record: a restore
    /// resolves thousands of links, and a fetch per link is the shape that turns a restore into a
    /// minute of spinning.
    init(existing context: ModelContext) {
        let songs = (try? context.fetch(FetchDescriptor<Song>())) ?? []
        self.songs = Dictionary(songs.map { ($0.sourceID, $0) }, uniquingKeysWith: { first, _ in first })
        self.loops = Dictionary(songs.flatMap(\.loops).map { ($0.uid, $0) },
                                uniquingKeysWith: { first, _ in first })
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        self.exercises = Dictionary(exercises.map { ($0.uid, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// An empty resolver, for a restore into an empty library and for tests.
    init() {}
}

/// Everything a restore will add, built and **not yet inserted** (ADR 0188 S3).
///
/// The same split S2 made, for the same reason: inserting a full object graph in the XCTest host
/// traps (`docs/swiftdata-gotchas.md`), so a writer that went straight to a `ModelContext` could only
/// ever be checked by hand on a device. Everything about *what a row becomes* is decided here, over
/// plain objects, and `insert(into:)` is the small ordered part that cannot be unit-tested.
@MainActor
struct RestoredLibrary {
    var songs: [Song] = []
    var exercises: [Exercise] = []
    var savedChords: [SavedChord] = []
    var routines: [(routine: Routine, items: [RoutineItem])] = []
    var goals: [Goal] = []
    var longTermGoals: [LongTermGoal] = []
    var runs: [PracticeRun] = []
    var journal: [JournalEntry] = []
    var takes: [(take: Recording, moments: [TakeNote])] = []
    var profile: Profile?

    /// Take audio to write out of the zip once the rows exist, keyed by file name (D7).
    var takeAudio: [String: ZipEntry] = [:]

    /// Reference pictures to write out of the zip once the rows exist, keyed by file name (D7).
    var referenceImages: [String: ZipEntry] = [:]

    /// How many rows this will add, by kind — asserted against the plan the player was shown.
    var rowCount: Int {
        songs.count + exercises.count + savedChords.count + routines.count + goals.count
            + longTermGoals.count + runs.count + journal.count + takes.count + (profile == nil ? 0 : 1)
    }

    /// Write the graph into `context`, in the one order that works.
    ///
    /// **Every to-many relationship is assigned after its owner is in the context**, never before.
    /// That is the house rule, not a preference: `RoutineLibraryView.duplicate(_:)` and
    /// `ExerciseLibraryView.duplicate(_:)` both insert and then assign, and `HydratedRoutine.insert`
    /// says so in as many words. `materialize` builds the graph whole — which is what makes it
    /// assertable in a test host that traps on inserting one — so the relationships are lifted off
    /// here, the owner goes in, and they go back on.
    ///
    /// Loops are the nested case: a song owns them and each of them owns its own links, so the links
    /// are re-attached after the loops are, rather than riding in on an assignment made before the
    /// song existed.
    func insert(into context: ModelContext) {
        for song in songs {
            let (loops, markers, references) = (song.loops, song.markers, song.references)
            let loopReferences = loops.map { ($0, $0.references) }
            context.insert(song)
            song.loops = loops
            song.markers = markers
            song.references = references
            for (loop, links) in loopReferences { loop.references = links }
        }
        for drill in exercises {
            let references = drill.references
            context.insert(drill)
            drill.references = references
        }
        savedChords.forEach(context.insert)
        for (routine, items) in routines {
            let references = routine.references
            context.insert(routine)
            routine.items = items
            routine.references = references
        }
        goals.forEach(context.insert)
        longTermGoals.forEach(context.insert)
        runs.forEach(context.insert)
        journal.forEach(context.insert)
        for (take, moments) in takes {
            context.insert(take)
            take.moments = moments
        }
        if let profile { context.insert(profile) }
    }
}

/// Turns a read archive into rows (ADR 0188 S3).
///
/// **Nothing here deletes or overwrites anything** (D6). A row whose key the library already has is
/// skipped entirely — not merged, not compared field by field, not replaced — which is what makes a
/// restore idempotent: running it twice leaves the library exactly as running it once did.
///
/// **A uid repeated inside one file produces one row.** An archive this app wrote cannot contain
/// two rows with one uid, and this door reads a file that may have been hand-edited or concatenated.
/// `RestorePlan` counts a repeat once, so without the same guard here the preview would promise a
/// number the writer then exceeded — and the result would be two rows sharing the key that every
/// journal entry, take and block joins on.
///
/// **Every enum column is assigned raw**, never through a typed setter, for the reason S2 wrote into
/// `ReceivedRoutineBuilder`: `ExerciseTemplate`, `Instrument`, `Subdivision` and
/// `MetronomeIntervalUnit` resolve with a `?? default` inside their getters, so a value this build
/// does not recognise would be normalised on the way in and the original written back as the default.
/// That matters more here than at the receive door, not less: this is the player's own library coming
/// back, and a field silently rewritten during a restore is data loss in the one operation whose
/// entire purpose is not losing any.
@MainActor
enum ArchiveRestoreWriter {

    /// Read the keys a plan needs off the store.
    ///
    /// Counted rather than fetched whole where nothing but the key is wanted — the resolver above
    /// fetches the three types a restore has to *point at*, and this fetches the identity of
    /// everything it might skip.
    static func existingKeys(in context: ModelContext) -> RestoreExistingKeys {
        var keys = RestoreExistingKeys()
        keys.songSourceIDs = Set(((try? context.fetch(FetchDescriptor<Song>())) ?? []).map(\.sourceID))
        keys.exerciseUIDs = Set(((try? context.fetch(FetchDescriptor<Exercise>())) ?? []).map(\.uid))
        keys.savedChordUIDs = Set(((try? context.fetch(FetchDescriptor<SavedChord>())) ?? []).map(\.uid))
        keys.routineUIDs = Set(((try? context.fetch(FetchDescriptor<Routine>())) ?? []).map(\.uid))
        keys.goalUIDs = Set(((try? context.fetch(FetchDescriptor<Goal>())) ?? []).map(\.uid))
        keys.longTermGoalUIDs = Set(((try? context.fetch(FetchDescriptor<LongTermGoal>())) ?? []).map(\.uid))
        keys.runUIDs = Set(((try? context.fetch(FetchDescriptor<PracticeRun>())) ?? []).map(\.uid))
        keys.journalUIDs = Set(((try? context.fetch(FetchDescriptor<JournalEntry>())) ?? []).map(\.uid))
        keys.takeUIDs = Set(((try? context.fetch(FetchDescriptor<Recording>())) ?? []).map(\.uid))
        keys.hasProfile = ((try? context.fetchCount(FetchDescriptor<Profile>())) ?? 0) > 0
        return keys
    }

    /// Build every row the archive adds, resolving links as it goes.
    ///
    /// The order is the dependency order, and it is not arbitrary: songs bring the loops that
    /// routines, journal entries and takes point at, and exercises are named by all three. A kind
    /// written before the thing it references would resolve to `nil` and land as an orphan — which is
    /// a real state in this app (`RoutineItem.isOrphaned`) and would be entirely fabricated here.
    static func materialize(_ read: ReadArchive,
                            existing: RestoreExistingKeys,
                            resolver: RestoreResolver = RestoreResolver()) -> RestoredLibrary {
        materialize(read.archive,
                    takeAudio: read.takeAudio,
                    referenceImages: read.referenceImages,
                    existing: existing,
                    resolver: resolver)
    }

    /// The same, over a payload with no zip behind it.
    ///
    /// This is the one the tests call, and the split is not a convenience: every rule about what a row
    /// becomes is decided from the payload alone, so a rule that could only be reached through a zip
    /// would be a rule tested through two layers of file format.
    static func materialize(_ archive: PracticeArchive,
                            takeAudio: [String: ZipEntry] = [:],
                            referenceImages: [String: ZipEntry] = [:],
                            existing: RestoreExistingKeys,
                            resolver: RestoreResolver = RestoreResolver()) -> RestoredLibrary {
        var resolver = resolver
        var landing = RestoredLibrary()

        addSongs(archive.songs, existing: existing, into: &landing, resolver: &resolver)
        addExercises(archive.exercises, existing: existing, into: &landing, resolver: &resolver)
        addSavedChords(archive.savedChords, existing: existing, into: &landing)
        addRoutines(archive.routines, existing: existing, into: &landing, resolver: resolver)
        addGoals(archive, existing: existing, into: &landing, resolver: resolver)
        addRuns(archive.practiceRuns, existing: existing, into: &landing)
        addJournal(archive.journal, existing: existing, into: &landing, resolver: resolver)
        addTakes(archive.takes, existing: existing, into: &landing, resolver: resolver)
        addProfile(archive.profile, existing: existing, into: &landing)

        // Only the files the rows being added actually name. An archive carries the pictures and
        // audio for its whole library, and a restore into a populated one may be adding a fraction of
        // it; writing the rest would put files in `Recordings/` and `References/` that no row points
        // at — precisely what ADR 0182's sweep exists to delete.
        let landingTakeNames = Set(landing.takes.map(\.take.fileName))
        landing.takeAudio = takeAudio.filter { landingTakeNames.contains($0.key) }
        let attachments = landing.referencedAttachmentNames
        landing.referenceImages = referenceImages.filter { attachments.contains($0.key) }
        return landing
    }
}

extension RestoredLibrary {
    /// Every attachment leaf name the rows being added actually point at.
    ///
    /// The filter matters: an archive carries the pictures for its whole library, and a restore into
    /// a populated one may be adding a fraction of it. Writing the rest would put files in
    /// `References/` that no row names — which is precisely what ADR 0182's sweep exists to delete,
    /// so they would survive until the player next pressed *Reclaim space* and then vanish.
    @MainActor
    var referencedAttachmentNames: Set<String> {
        var names: Set<String> = []
        for song in songs {
            names.formUnion(song.references.map(\.attachmentFileName))
            names.formUnion(song.loops.flatMap(\.references).map(\.attachmentFileName))
        }
        names.formUnion(exercises.flatMap(\.references).map(\.attachmentFileName))
        names.formUnion(routines.flatMap { $0.routine.references }.map(\.attachmentFileName))
        names.remove("")
        return names
    }
}
