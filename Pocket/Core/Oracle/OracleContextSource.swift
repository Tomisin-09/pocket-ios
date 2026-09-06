import Foundation

/// Everything `OracleContextBuilder` reads, gathered by the caller (ADR 0187 D5).
///
/// Explicit arrays rather than a `ModelContext` to fetch from, for the reason
/// `ArchiveSource.swift:5-8` gives and this feature needs twice over: it keeps the builder free of
/// SwiftData, so the rules about what may cross the wire are unit-tested over plain **uninserted**
/// models — inserting into a container traps in the XCTest host — and it leaves the caller in
/// charge of which rows go in.
///
/// That second half is not incidental here. The builder holds D6, and D6 is the privacy contract.
/// The moment this takes a `ModelContext`, the rules become untestable and the contract becomes a
/// promise instead of a mechanism.
@MainActor
struct OracleContextSource {
    var exercises: [Exercise] = []
    var loops: [Loop] = []
    var journal: [JournalEntry] = []
    var takes: [Recording] = []
    var goals: [Goal] = []
    var longTermGoals: [LongTermGoal] = []
    /// Already a flat, store-free value (`SessionRecord`), so the log arrives mapped rather than as
    /// `[PracticeRun]` — the same reuse ADR 0181 made when it exported the log as-is.
    var records: [SessionRecord] = []
}
