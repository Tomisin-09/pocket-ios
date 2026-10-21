import Foundation
import SwiftData

/// **The app's one persistent store**: which models it holds, and where it lives.
///
/// **It lives in the app's own Application Support, and `groupContainer: .none` is what keeps it
/// there.** SwiftData's default is `.automatic`, which puts the store in the first App Group the app is
/// entitled to. The app has had one since ADR 0264 (*Save to Red Moon*'s snapshot and inbox), and left
/// at the default, the first launch of a build with the group **copied the whole store into the group
/// container and ran from the copy**, leaving the original behind, unread. That was seen on the
/// simulator on 2026-10-21, before anything shipped. It is the move ADR 0264 and 0186 D9 refused:
/// every player's library relocated to power a picker. No in-memory test can see it, and CI builds
/// unsigned, with no group, so `PocketStoreTests` pins the URL instead.
enum PocketStore {
    /// Every model the store holds.
    static let models: [any PersistentModel.Type] = [
        Song.self, Loop.self, Marker.self, JournalEntry.self,
        Exercise.self, Routine.self, RoutineItem.self, Goal.self,
        LongTermGoal.self, Recording.self, TakeNote.self, SavedChord.self, Profile.self,
        PracticeRun.self, ReferenceLink.self, LoopSpanChange.self,
        Snag.self, PracticeFolder.self, CustomSkill.self, SavedProgression.self,
        WrittenTab.self
    ]

    /// `Application Support/default.store`, where it has always been, and never a group container. No
    /// CloudKit either: the app has no iCloud entitlement, and `.automatic` is the same trap waiting for
    /// one.
    static var configuration: ModelConfiguration {
        ModelConfiguration(groupContainer: .none, cloudKitDatabase: .none)
    }

    /// The store the app runs on. A store that won't open traps, as it always has (ADR 0189).
    static func container() -> ModelContainer {
        do {
            return try ModelContainer(for: Schema(models), configurations: configuration)
        } catch {
            fatalError("The store couldn't be opened: \(error)")
        }
    }
}
