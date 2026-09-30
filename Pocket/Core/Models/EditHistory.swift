import Foundation

/// One step an `EditHistory` can put back: what an editor looked like **before** a change, and where it
/// was. Each editor says what counts as a change and where an undo lands, since only it knows what it holds.
protocol EditStep: Equatable, Sendable {
    /// Where the editor was: moved by an undo or a redo, never a change on its own.
    var active: Int { get set }
    /// Whether `other` differs in anything the history restores. Where the editor was never counts.
    func changes(_ other: Self) -> Bool
    /// Where an undo or redo from `current` to this step lands: in front of what changed.
    func landing(from current: Self) -> Int
}

/// **Undo and redo** for an editor (ADR 0234 D6, made generic by ADR 0235 D9): every change on this visit,
/// one step each, so it can be put back and put back again. Name the notes keeps its steps as
/// `NamingHistory`; a written tab keeps its own.
///
/// It lasts for the visit. Pure and SwiftUI-free (AGENTS.md), so the rules are unit-tested.
struct EditHistory<Content: EditStep>: Equatable, Sendable {

    typealias Step = Content

    /// Enough for a long session, and a bound, so a visit can't grow it without end. Computed, because a
    /// generic type can't store a static.
    static var limit: Int { 100 }

    private(set) var undos: [Step] = []
    private(set) var redos: [Step] = []

    var canUndo: Bool { !undos.isEmpty }
    var canRedo: Bool { !redos.isEmpty }

    /// Remember `before` as one step, when the change actually changed something the history restores. A
    /// fresh change ends the redo trail, as it does everywhere else.
    mutating func record(_ before: Step, now after: Step) {
        guard before.changes(after) else { return }
        undos.append(before)
        if undos.count > Self.limit { undos.removeFirst(undos.count - Self.limit) }
        redos.removeAll()
    }

    /// The step to go back to, with the editor moved to what changed; `nil` when there's none.
    mutating func undo(from current: Step) -> Step? {
        guard var step = undos.popLast() else { return nil }
        redos.append(current)
        step.active = step.landing(from: current)
        return step
    }

    /// The step undone last, put back, with the editor on what it changed; `nil` when there's none.
    mutating func redo(from current: Step) -> Step? {
        guard var step = redos.popLast() else { return nil }
        undos.append(current)
        step.active = step.landing(from: current)
        return step
    }

    /// The first place two runs differ, so what changed is in front of the player; `fallback` when they're
    /// the same. Something taken out or added lands where it was. Never past the end of `restored`.
    static func landing<Element: Equatable>(from current: [Element], to restored: [Element],
                                            otherwise fallback: Int) -> Int {
        guard !restored.isEmpty else { return 0 }
        let shared = min(current.count, restored.count)
        let differing = (0..<shared).first { current[$0] != restored[$0] }
            ?? (current.count == restored.count ? nil : shared)
        return min(max(differing ?? fallback, 0), restored.count - 1)
    }
}
