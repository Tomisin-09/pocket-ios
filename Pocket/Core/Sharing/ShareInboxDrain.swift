import Foundation
import SwiftData
import UniformTypeIdentifiers

/// **The app files what *Save to Red Moon* saved** (ADR 0264 D9), when it comes to the foreground.
///
/// Every save goes through `ReferenceLinkStore`, so the http/https rule and the attachment rules (0167
/// phase 2: a picture cut down to size, the 25 MB ceiling, five files a place) apply exactly as they do
/// in the app. Pictures are cut down here and not in the extension, which runs under a much tighter
/// memory limit.
@MainActor
enum ShareInboxDrain {

    /// File every finished save in `directory`'s inbox, oldest first, and clear it. Returns how many
    /// were filed.
    ///
    /// The store is saved before the inbox is cleared, and a save already in the store (its id is a
    /// reference's uid) is cleared without filing it again, so stopping between the two never files
    /// twice. A save the store can't take at all, a file it can't read, is cleared too: it would be
    /// refused every time.
    @discardableResult
    static func drain(from directory: URL, standing: PlanStanding, in context: ModelContext,
                      _ fileManager: FileManager = .default) -> Int {
        let pending = ShareInbox.pending(in: directory, fileManager)
        guard !pending.isEmpty else { return 0 }
        let owners = Dictionary(ReferenceOwners.all(in: context).map { ($0.destination.id, $0.owner) },
                                uniquingKeysWith: { first, _ in first })
        let existing = Set(((try? context.fetch(FetchDescriptor<ReferenceLink>())) ?? []).map(\.uid))

        var filed = 0
        var done: [ShareInbox.Pending] = []
        for save in pending {
            defer { done.append(save) }
            guard !existing.contains(save.item.id) else { continue }
            let owner = save.item.destination.flatMap { owners[$0] }
            let target = owner.flatMap { owner in
                ReferencePlaceKind(owner).map { ShareInboxPlan.Target(kind: $0, canTakeFile: owner.canAddAttachment) }
            }
            let place: any ReferenceLinkOwner = switch ShareInboxPlan.filing(for: save.item, target: target,
                                                                              standing: standing) {
            case .place: owner ?? KeepForLater()
            case .keepForLater: KeepForLater()
            }
            if file(save, on: place, in: context, fileManager) { filed += 1 }
        }
        guard (try? context.save()) != nil else { return 0 }
        for save in done { ShareInbox.remove(save, fileManager) }
        return filed
    }

    /// Write one save onto `owner`. `false` when the store refuses it.
    private static func file(_ save: ShareInbox.Pending, on owner: some ReferenceLinkOwner,
                             in context: ModelContext, _ fileManager: FileManager) -> Bool {
        let item = save.item
        let link: ReferenceLink?
        if let fileURL = save.fileURL {
            guard let data = try? Data(contentsOf: fileURL) else { return false }
            link = try? ReferenceLinkStore.addAttachment(data, contentType: item.typeIdentifier.flatMap(UTType.init),
                                                         title: item.title, note: item.note, uid: item.id,
                                                         to: owner, in: context, fileManager)
        } else if let url = item.url {
            link = ReferenceLinkStore.add(title: item.title, url: url, note: item.note, to: owner, in: context)
            link?.uid = item.id
        } else {
            link = nil
        }
        link?.dateAdded = item.savedAt
        return link != nil
    }
}

/// Every place a reference can go, and the model behind it: what the snapshot lists and what a save is
/// filed onto. Saved routines only: a temporary session (ADR 0243) is replaced by the next Start.
enum ReferenceOwners {
    struct Place {
        let destination: ReferenceDestination
        let owner: any ReferenceLinkOwner
    }

    @MainActor
    static func all(in context: ModelContext) -> [Place] {
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let routines = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        let songs = (try? context.fetch(FetchDescriptor<Song>())) ?? []
        let loops = (try? context.fetch(FetchDescriptor<Loop>())) ?? []
        // Typed statements, not one `+` chain: CI's Xcode 16 timed out on that shape (slice 1).
        var all: [Place] = exercises.map { Place(destination: ReferenceDestination(exercise: $0), owner: $0) }
        all += Routine.saved(routines).map { Place(destination: ReferenceDestination(routine: $0), owner: $0) }
        all += songs.map { Place(destination: ReferenceDestination(song: $0), owner: $0) }
        all += loops.map { Place(destination: ReferenceDestination(loop: $0), owner: $0) }
        return all
    }
}

extension ReferencePlaceKind {
    /// The kind of an owner model. `nil` for *Keep for later*, which is no place.
    init?(_ owner: any ReferenceLinkOwner) {
        switch owner {
        case is Exercise: self = .exercise
        case is Routine: self = .routine
        case is Song: self = .song
        case is Loop: self = .loop
        default: return nil
        }
    }
}

extension ShareOwnerSnapshot {
    /// The snapshot of the library as it is now (D9).
    @MainActor
    init(context: ModelContext, standing: PlanStanding, appearance: AppearancePreference) {
        let all = ReferenceOwners.all(in: context)
        self.init(standing: standing, appearance: appearance, places: all.map(\.destination),
                  fullOfFiles: Set(all.filter { !$0.owner.canAddAttachment }.map(\.destination.id)))
    }
}
