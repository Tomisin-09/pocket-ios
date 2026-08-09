import Foundation
import SwiftData

/// Whole-library reads that exist only to *offer* something — tag and collection suggestions
/// while typing, the candidate list behind a link picker.
///
/// These were `@Query` properties on the sheets that use them. A `@Query` for an entire entity
/// runs on the main thread while the sheet is being presented, and it faults every object it
/// returns to reach the one array it wants (`loop.tags`, `song.collections`). Two of these
/// sheets open from the practice screen *over playing audio*, where that read landed as a
/// visible hitch on present. Fetching on demand from a `.task` moves it behind the first
/// frame: the sheet appears at once and the suggestions arrive a moment later, which is the
/// right trade for a convenience list.
///
/// Nothing here is a source of truth — a pool that hasn't loaded yet costs the user a
/// suggestion, never a correct value.
@MainActor
enum LibraryPools {

    /// Every tag on every loop in the library (unnormalised — `Labels.suggestions` dedupes).
    static func loopTags(in context: ModelContext) -> [String] {
        (try? context.fetch(FetchDescriptor<Loop>()))?.flatMap(\.tags) ?? []
    }

    /// Every collection name on every song.
    static func songCollections(in context: ModelContext) -> [String] {
        (try? context.fetch(FetchDescriptor<Song>()))?.flatMap(\.collections) ?? []
    }

    /// Every *other* song's genre — the pool `Labels.canonicalSingle` matches against so a
    /// re-typed genre snaps to the spelling already in use. Read at save time, not at
    /// presentation: it's needed once, on an explicit action, where a fetch is unremarkable.
    static func songGenres(in context: ModelContext, excluding song: Song) -> [String] {
        (try? context.fetch(FetchDescriptor<Song>()))?
            .filter { $0 !== song }
            .map(\.genre) ?? []
    }

    /// Every exercise, by name — the candidate list for the "Link exercises" picker.
    static func exercisesByName(in context: ModelContext) -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
