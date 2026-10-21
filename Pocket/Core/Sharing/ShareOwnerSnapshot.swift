import Foundation

/// **What *Save to Red Moon* knows about the library** (ADR 0264 D9): every place a reference can go, as
/// the picker draws it, and where the player stands with the plan. The app writes it; the extension,
/// which can't open the store, only reads it.
///
/// It holds only what its reader renders (0183 D1, 0186 D9): a place's key, kind, name, parent and
/// when it was last practised, which places hold as many files as they may, the plan standing and the
/// appearance. No notes, no history, no tempos.
///
/// **A stale snapshot is safe.** The drain decides again against the store when it files a save
/// (`ShareInboxPlan`), so a place deleted since, a place that has filled up, or a plan that has changed
/// sends the save to *Not filed* rather than losing it. And D6's standings only ever move forward: a
/// stale `lapsed` can be wrong about a lock, never about what's offered.
struct ShareOwnerSnapshot: Codable, Equatable, Sendable {
    static let fileName = "owners.json"

    var standing: PlanStanding
    /// The player's choice in Settings ▸ Appearance, so the extension draws as the app does.
    var appearance: AppearancePreference
    /// Every place, unsorted: `ReferenceDestinationPicker` orders them.
    var places: [ReferenceDestination]
    /// The places that hold `ReferenceAttachmentStore.maxPerOwner` files already, by
    /// `ReferenceDestination.id`. Only a shared file reads them.
    var fullOfFiles: Set<String> = []
}

extension ShareOwnerSnapshot {
    /// The snapshot in `directory`, or `nil` when there isn't one or it can't be read.
    static func read(from directory: URL) -> ShareOwnerSnapshot? {
        let file = directory.appending(path: fileName, directoryHint: .notDirectory)
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(ShareOwnerSnapshot.self, from: data)
    }

    /// Replace the snapshot in `directory`. Atomic, so the extension never reads half of one.
    func write(to directory: URL) throws {
        let file = directory.appending(path: Self.fileName, directoryHint: .notDirectory)
        try JSONEncoder().encode(self).write(to: file, options: .atomic)
    }
}

extension AppearancePreference: Codable {}
