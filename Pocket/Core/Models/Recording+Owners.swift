import Foundation

/// `recordingsByRecent` for each take owner — newest-first, the order the Takes list surfaces them
/// in (mirroring `journalByRecent`). Kept in their own file so `Song.swift` stays under the
/// 400-line cap. Reading `recordings` here tracks the SwiftData relationship, so the Takes UI
/// refreshes when a take is added or deleted (ADR 0069, slice 3).
extension Loop {
    var recordingsByRecent: [Recording] { recordings.sorted { $0.createdAt > $1.createdAt } }
}

extension Exercise {
    var recordingsByRecent: [Recording] { recordings.sorted { $0.createdAt > $1.createdAt } }
}

extension Song {
    var recordingsByRecent: [Recording] { recordings.sorted { $0.createdAt > $1.createdAt } }
}
