import Foundation

/// A tab being written (ADR 0235 D3, D4): its content, and where the writer is in it. The strip has **one
/// open slot, a +**: at the end while writing, or in front of a note after *Insert before*. Either a note is
/// picked or the + is lit, and what the neck, *Bar line* and *Section* do follows from which.
///
/// The shared neck editor sees the notes with an empty note at the +, so *Into it*, the marks and the
/// neighbours work on the writer exactly as on Name the notes, and a tap on the neck comes here to become a
/// new note or a changed one. The slot is never stored: a written tab is only its content.
///
/// Pure and SwiftUI-free (AGENTS.md), so the rules are unit-tested.
struct TabDraft: Equatable, Sendable {
    private(set) var content: TabContent
    /// Where the + is, `0...count`.
    private(set) var slot: Int
    /// The note picked, or `nil` while the + is lit.
    private(set) var selected: Int?
    /// The note the marks go on, when one has been placed or picked.
    private(set) var marked: Int?
    /// A shape's ringed string, *Chords*, and *Into it* waiting: the neck editor's, kept here.
    var ringed: Int?
    var chordsOn = false
    var awaitingStart: LeadInRequest?

    /// Opened at the end, with the marks on the last note, as the writer opens.
    init(content: TabContent) {
        self.content = content.normalised
        self.slot = self.content.count
        self.selected = nil
        self.marked = self.content.labels.indices.last
        self.ringed = marked.flatMap { self.content.labels[$0]?.frettedNotes.last?.string }
    }

    var count: Int { content.count }
    var isEmpty: Bool { content.labels.isEmpty }

    /// Where *Bar line* and *Section* act: the lit chip, the + or the note picked.
    var position: Int { selected ?? slot }

    // MARK: - What the neck editor sees

    /// The notes with an empty note at the +.
    var editorLabels: [PieceLabel?] {
        var labels = content.labels
        labels.insert(nil, at: slot)
        return labels
    }

    /// The editor's cursor: on the picked note or the +, the marks on `marked` when it isn't that.
    var cursor: NeckCursor {
        let active = selected ?? slot
        return NeckCursor(active: active, placedNote: marked == active ? nil : marked, ringed: ringed,
                          chordsOn: chordsOn, awaitingStart: awaitingStart)
    }

    /// Take the editor's ringed string, *Chords* and *Into it* back. Where it is stays this draft's to say.
    mutating func adopt(_ cursor: NeckCursor) {
        ringed = cursor.ringed
        chordsOn = cursor.chordsOn
        awaitingStart = cursor.awaitingStart
    }

    /// The editor's notes written back (a mark, a join, a lead-in): the + dropped out again.
    mutating func write(editorLabels labels: [PieceLabel?]) {
        guard labels.count == count + 1, labels.indices.contains(slot) else { return }
        var notes = labels
        let atSlot = notes.remove(at: slot)
        content.labels = notes
        if let atSlot { insert(atSlot) } else { content = content.normalised }
    }

    // MARK: - The neck

    /// A tap on the neck. On the + it's a **new note**: the + moves on past it, the marks go on it, and with
    /// *Chords* on the strip stays on it, since a shape takes several taps. On a note it **changes** it (by
    /// `NeckPlacement`, so its marks stay) and moves on. While *Into it* waits, the tap says where the note
    /// started.
    mutating func place(string: Int, fret: Int) {
        if let request = awaitingStart {
            let edit = NeckEditing.takeStart(string: string, fret: fret, for: request, labels: editorLabels,
                                             cursor: cursor)
            adopt(edit.cursor)
            write(editorLabels: edit.labels)
            return
        }
        guard let note = selected else {
            let outcome = NeckPlacement.tap(string: string, fret: fret, on: nil, ringed: nil, chords: chordsOn)
            ringed = outcome.ringed
            insert(outcome.label)
            return
        }
        let outcome = NeckPlacement.tap(string: string, fret: fret, on: content.labels[note], ringed: ringed,
                                        chords: chordsOn)
        ringed = outcome.ringed
        content.labels[note] = outcome.label
        content = content.normalised
        marked = note
        if !chordsOn { selected = next(after: note) }
    }

    private mutating func insert(_ label: PieceLabel) {
        let index = slot
        content = content.inserting(label, at: index)
        marked = index
        slot = index + 1
        selected = chordsOn ? index : nil
    }

    /// Where the strip goes after a note is changed: the + when it sits just after it, else the next note,
    /// else the + at the end.
    private func next(after note: Int) -> Int? {
        if note == slot - 1 { return nil }
        if note + 1 < count { return note + 1 }
        return slot == count ? nil : note
    }

    // MARK: - The strip

    /// Pick a note: the neck changes it. The + goes back to the end.
    mutating func pick(_ note: Int) {
        guard content.labels.indices.contains(note) else { return }
        slot = count
        selected = note
        marked = note
        awaitingStart = nil
        ringed = content.labels[note]?.frettedNotes.last?.string
    }

    /// Light the +, sent back to the end, with the marks on the last note.
    mutating func pickEnd() {
        slot = count
        selected = nil
        marked = content.labels.indices.last
        awaitingStart = nil
        ringed = marked.flatMap { content.labels[$0]?.frettedNotes.last?.string }
    }

    /// The + lit where it is: in front of a note after *Insert before*, when a shape written there with
    /// *Chords* on had the strip on it.
    mutating func lightSlot() {
        selected = nil
        marked = slot == count ? content.labels.indices.last : nil
        awaitingStart = nil
    }

    /// *Insert before N*: the + in front of note N, lit. Each tap adds one more there.
    mutating func insertBefore(_ note: Int) {
        guard content.labels.indices.contains(note) else { return }
        slot = note
        selected = nil
        marked = nil
        awaitingStart = nil
    }

    /// *Take note N out*: the note after drops its join; the strip stays on what's now note N, or the + if
    /// it was the last.
    mutating func takeOut(_ note: Int) {
        guard content.labels.indices.contains(note) else { return }
        content = content.removing(at: note)
        slot = count
        selected = note < count ? note : nil
        marked = selected ?? content.labels.indices.last
        awaitingStart = nil
    }

    /// *Bar line* at the lit chip. Refused before the first note and where a section starts.
    mutating func toggleBar() {
        content = content.togglingBar(at: position)
    }

    /// *Section* at the lit chip: start or rename one, or with `nil` take the heading off, keeping its bar.
    mutating func setSection(_ name: String?) {
        content = content.settingSection(at: position, name: name)
    }

    /// New strings (`NamingTuning.carrying`): a new tuning keeps the frets, a new instrument clears them.
    /// The bar lines and sections stay, so the tab keeps its shape and its notes can be placed again.
    mutating func retune(_ labels: [PieceLabel?]) {
        guard labels.count == count else { return }
        content.labels = labels
        content = content.normalised
        awaitingStart = nil
    }

    // MARK: - Undo (ADR 0234 D6, for a tab)

    /// The draft as a step of the history: its content, and the note picked, or the end.
    var step: TabStep { TabStep(content: content, active: selected ?? count) }

    /// A step put back: on the note it changed, else where it was.
    mutating func restore(_ step: TabStep) {
        content = step.content.normalised
        awaitingStart = nil
        if step.active < count {
            pick(step.active)
        } else {
            pickEnd()
        }
    }
}

/// One step of the writer's history: the whole content (notes, bar lines, sections), so a heading taken off
/// comes back with its notes as one step; the strings, since a new instrument clears the frets and undoing
/// it has to bring the strings back with them; and where the writer was.
struct TabStep: EditStep {
    var content: TabContent
    /// The note picked, or the note count for the + at the end.
    var active: Int
    /// The strings, set by the writer, which holds them (`TabDraft` doesn't).
    var openMidi: [Int] = []
    var tuningLabel = ""

    func changes(_ other: TabStep) -> Bool { content != other.content || openMidi != other.openMidi }

    /// The first note that differs, so what changed is in front of the player; where it was when only a bar
    /// line or a heading did, the + at the end included.
    func landing(from current: TabStep) -> Int {
        let now = current.content.labels
        let then = content.labels
        let shared = min(now.count, then.count)
        let differing = (0..<shared).first { now[$0] != then[$0] } ?? (now.count == then.count ? nil : shared)
        if let differing, differing < then.count { return differing }
        return min(active, then.count)
    }
}
