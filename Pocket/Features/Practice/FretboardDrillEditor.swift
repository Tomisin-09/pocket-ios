import SwiftUI

/// The **fretboard template's authoring editor** (ADR 0065 build 2). The "steps lane + tap-to-place"
/// model: a segmented control sets the subdivision, a **slot strip** shows the bar's note slots (tap to
/// select one), and an interactive **fretboard** places a note into the selected slot (tap advances;
/// tapping a slot's own note clears it). A fret-**position** control scrolls the visible window up the
/// neck, so a drill can sit anywhere. **Undo/Clear** step back or wipe the taps.
///
/// A thin skin over `FretboardDrill`'s pure ops (`replacingNote`, `resized`, `cleared`) — the view maps
/// taps to those and draws the result, holding no timing logic of its own (T5). Colours are semantic
/// `PocketColor` roles (T10). A `FretboardDrillPreview` sits above the board — board shows *where*, the
/// preview *when* — so "watch it before you save" works for a hand-placed drill too.
struct FretboardDrillEditor: View {
    /// Beats per bar (the exercise's meter) — fixes how many slots each subdivision produces.
    let beatsPerBar: Int
    @Binding var drill: FretboardDrill
    var tint: Color = PocketColor.practice
    /// When set, shows the **guide** — a reference + key picker whose notes are ghosted on the board so
    /// a player can trace and tap them. Off for plain custom drills; the "draw your own" surfaces turn it
    /// on. Purely a drawing aid — nothing snaps.
    var referenceEnabled: Bool = false
    /// The catalog the guide lists — the **scale** references by default (the custom-scale canvas, incl.
    /// the symmetric scales the box generator can't produce), or the **arpeggio** chord-tone shapes for
    /// the Arpeggios "draw your own" surface. Only consulted when `referenceEnabled`.
    var guideCatalog: [ScaleReference] = ScaleReference.all

    /// The slot the next placed note lands in — highlighted in the strip and reflected on the board.
    /// Non-private so the board half of this editor (`+Board.swift`) can read it.
    @State var selectedSlot = 0
    /// The fret the horizontally-scrollable neck should scroll into view — set when a placed slot is
    /// selected so its note comes into view, consumed by the board's `ScrollViewReader`.
    @State var scrollTargetFret: Int?
    /// The board cell currently **pulsing** — set when a slot carrying that note is selected, cleared
    /// shortly after, so the eye is led from the strip to the dot (2026-07-28). `pulseToken` retriggers
    /// the clear-after task when the *same* cell is tapped twice, which `pulsingCell` alone wouldn't.
    @State var pulsingCell: FretNote?
    @State private var pulseToken = 0
    /// The global note-caption preference — shown on the preview strip above (not on the placement
    /// board below, which stays focused on *where*, not *what*). Shared with every other fretboard
    /// editor and the live practice run (ADR 0065 T10).
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    /// A hand-placed drill usually names no root, so an Interval mode inherited from a scale editor
    /// resolves to Off here rather than silently drawing no captions at all (2026-07-28).
    private var labelMode: FretLabelMode {
        (FretLabelMode(rawValue: storedLabelMode) ?? .none).resolved(hasRoot: hasRoot)
    }
    /// Whether this drill names a tonal centre — a hand-drawn board doesn't; one promoted from a
    /// generated run can.
    private var hasRoot: Bool { drill.rootPitchClass != nil }
    /// A one-shot "watch it" request (ADR 0065) — set by `FretboardPlayOnceButton`, read by the
    /// preview below. The walking-highlight preference itself lives only in Settings ("Animate
    /// exercises") now; Watch covers "see it move once" here without a redundant local toggle.
    @State private var playOnceToken: Date?
    /// The scale being ghosted as a tracing guide (`nil` = off), and its key (root pitch class). Only
    /// consulted when `referenceEnabled` — the guide overlay on the placement board. Non-private so the
    /// guide controls in `FretboardDrillEditor+Guide.swift` can bind them (same-module split).
    @State var referenceScale: ScaleReference?
    @State var referenceRoot = 0   // C
    /// A guide reference is a bare formula — the symmetric scales that motivated the canvas belong to no
    /// key signature at all — so its key menu spells by the accidental preference (ADR 0123). Non-private
    /// for the same-module split, like the guide bindings above.
    @AppStorage(AppSettings.Key.accidentalPreference)
    var accidentalRaw = NoteSpelling.default.rawValue
    /// Undo stack of drill snapshots — one per note edit, so **Undo** steps back a tap and **Clear** is
    /// reversible (2026-07-23). Holds only the *drill*, never the guide; capped to stay bounded.
    @State private var history: [FretboardDrill] = []
    private static let maxHistory = 100

    /// How the guide's key menu spells its roots — the preference, since a bare formula names no key.
    var guideSpelling: NoteSpelling { NoteSpelling(rawValue: accidentalRaw) ?? .default }

    /// Whether the guide is on and a scale is chosen.
    var referenceActive: Bool { referenceEnabled && referenceScale != nil }
    /// The pitch classes the guide ghosts, for the chosen scale + key.
    var referencePitchClasses: Set<Int> {
        referenceScale?.pitchClasses(root: referenceRoot) ?? []
    }
    /// Per-note duration matching the preview walk, so Hear stays locked to the highlight (ADR 0097 S4).
    private var secondsPerNote: Double {
        60.0 / Double(FretboardDrillPreview.previewBPM) / Double(max(1, drill.notesPerBeat))
    }
    /// The hand-placed grid as MIDI, in slot order — empty cells stay `nil` (rests) so Hear keeps its
    /// slots aligned to the walking highlight (ADR 0097 S4).
    private var heardNotes: [Int?] { drill.notes.map { $0.map(CAGEDShape.midi) } }

    /// The full neck the scrollable board draws — frets 0…`maxFret`. Wide enough for any hand position;
    /// the board scrolls horizontally rather than paging a 5-fret window (device feedback 2026-07-23).
    /// **24, not 22** (2026-07-28): `FretboardDrill` already accepted the full range and only this editor
    /// capped it, and 24 gives the octave double-inlay at 12 the partner that tells the two apart.
    static let maxFret = 24
    /// Ceiling on the Bars stepper — a custom drill can span up to this many bars of the exercise meter.
    private static let maxBars = 8
    private var barCount: Int { drill.barCount(beatsPerBar: beatsPerBar) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FretboardDisplayOptionsBar(heardNotes: heardNotes, secondsPerNote: secondsPerNote,
                                       playToken: $playOnceToken, tint: tint, hasRoot: hasRoot)
            FretboardDrillPreview(drill: drill, tint: tint, labelMode: labelMode,
                                  playOnceToken: playOnceToken)
            resolutionPicker
            barsStepper
            slotStrip
            if referenceEnabled { guideControls }
            board
            editControls
            Text("Pick a slot, then tap a fret to place a note. Tap a placed note to clear it. "
                 + "Swipe the neck to reach any fret; filling the last slot adds a bar.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .hearStopsOnDisappear()
        .task(id: pulseToken) {
            guard pulsingCell != nil else { return }
            try? await Task.sleep(for: .seconds(Self.pulseSeconds))
            pulsingCell = nil
        }
    }

    // MARK: - Subdivision

    /// A segmented resolution picker (shown inline, not under an Advanced disclosure like the generative
    /// editors) — changing it re-grids the drill, so it stays a primary control.
    private var resolutionPicker: some View {
        Picker("Subdivision", selection: resolutionBinding) {
            ForEach(FretboardSubdivisions.options, id: \.perBeat) { resolution in
                Text(resolution.label).tag(resolution.perBeat)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Fretboard subdivision")
    }

    /// Re-grids the drill when the subdivision changes, preserving notes by beat (pure `resized`), and
    /// keeps the selection in range so a coarser grid can't strand it past the end.
    private var resolutionBinding: Binding<Int> {
        Binding(
            get: { drill.notesPerBeat },
            set: { newPerBeat in
                mutate { $0.resized(notesPerBeat: newPerBeat, beatsPerBar: beatsPerBar) }
                selectedSlot = min(selectedSlot, max(0, drill.notes.count - 1))
                haptic(.light)
            })
    }

    // MARK: - Bars

    /// A stepper for how many bars the run spans (1…`maxBars`) — growing appends empty bars, shrinking
    /// drops the trailing ones (pure `withBarCount`). Slots-per-bar follow the meter × subdivision, so a
    /// longer run in a wider time signature naturally holds more slots.
    private var barsStepper: some View {
        Stepper(value: barsBinding, in: 1...Self.maxBars) {
            Text("Bars: \(barCount)")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
        }
        .tint(PocketColor.practice)
        .accessibilityLabel("Bars")
        .accessibilityValue("\(barCount)")
    }

    private var barsBinding: Binding<Int> {
        Binding(
            get: { barCount },
            set: { newBars in
                mutate { $0.withBarCount(newBars, beatsPerBar: beatsPerBar) }
                selectedSlot = min(selectedSlot, max(0, drill.notes.count - 1))
                haptic(.light)
            })
    }

    // MARK: - Slot strip

    /// The slots, grouped by beat, with a drawn **bar line** between bars — the way a stave reads, so
    /// which slot belongs to which bar is visible without counting (device feedback 2026-07-29).
    ///
    /// Beat groups stay the wrapping unit rather than whole bars: a bar of sixteenths is 16 cells and
    /// would overflow the screen as one unsplittable item, where a beat always fits. The gap is tuned
    /// so **two bars of quarters land on one row** — the common case for a short run — which the old
    /// 12pt spacing missed by a single cell.
    private var slotStrip: some View {
        FlowLayout(spacing: Self.groupSpacing) {
            ForEach(Array(stripItems.enumerated()), id: \.offset) { _, item in
                switch item {
                case .beat(let group):
                    HStack(spacing: 2) {
                        ForEach(group, id: \.self) { index in slotCell(index) }
                    }
                case .barLine:
                    barLine
                }
            }
        }
    }

    /// Gap between beat groups (and around a bar line). Deliberately tight: eight quarter-note cells
    /// plus a bar line have to clear one row on the narrowest phone.
    private static let groupSpacing: CGFloat = 4

    /// One entry in the strip — a beat's worth of slots, or the line that closes a bar.
    private enum StripItem {
        case beat([Int])
        case barLine
    }

    /// The strip's items in order: each bar's beat groups, separated by a bar line. The final bar gets
    /// no trailing line — a run ends, it isn't closed off.
    private var stripItems: [StripItem] {
        let perBeat = max(1, drill.notesPerBeat)
        let perBar = perBeat * max(1, beatsPerBar)
        var items: [StripItem] = []
        for barStart in stride(from: 0, to: drill.notes.count, by: perBar) {
            if barStart > 0 { items.append(.barLine) }
            let barEnd = min(barStart + perBar, drill.notes.count)
            for beatStart in stride(from: barStart, to: barEnd, by: perBeat) {
                items.append(.beat(Array(beatStart..<min(beatStart + perBeat, barEnd))))
            }
        }
        return items
    }

    /// The bar line itself — drawn rather than a literal "|" glyph so it keeps its weight and height
    /// against the slot cells at any Dynamic Type size.
    private var barLine: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(PocketColor.textSecondary.opacity(0.55))
            .frame(width: 2, height: 34)
            .accessibilityHidden(true)
    }

    private func slotCell(_ index: Int) -> some View {
        let note = drill.notes.indices.contains(index) ? drill.notes[index] : nil
        let isSelected = index == selectedSlot
        return Button {
            select(index, note: note)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(PocketColor.surfaceSubtle)
                    .frame(width: 32, height: 42)
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isSelected ? tint : .clear, lineWidth: 2)
                    .frame(width: 32, height: 42)
                slotGlyph(note)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Slot \(index + 1): \(slotAccessibility(note))")
        .accessibilityHint("Tap to select")
    }

    /// Select a slot and **link it to the board**: scroll its note into view (as before) and pulse the
    /// dot itself (2026-07-28). Sequenced runs reuse the same frets at several steps, and the strip
    /// used to leave you hunting for which dot the selected step meant — scrolling alone didn't say
    /// *which* of the dots now on screen it was. Dot sizes stay as they are; only the link is new.
    private func select(_ index: Int, note: FretNote?) {
        selectedSlot = index
        if let note {
            scrollTargetFret = note.fret
            pulsingCell = note
            pulseToken += 1
        }
        haptic(.light)
    }

    /// How long a tapped dot stays enlarged before easing back.
    private static let pulseSeconds: Double = 0.45

    @ViewBuilder
    private func slotGlyph(_ note: FretNote?) -> some View {
        if let note {
            VStack(spacing: 0) {
                Text(FretboardGrid.stringName(note.string, of: drill.stringCount))
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
                Text("\(note.fret)")
                    .font(.futura(.headline, weight: .semibold))
                    .foregroundStyle(tint)
            }
        } else {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(PocketColor.textSecondary.opacity(0.5))
        }
    }

    // MARK: - Edits (map a tap to a pure op)

    /// Place `cell` into the selected slot and advance; tapping the slot's own note (or "Rest" with
    /// `nil`) clears it instead. Non-private so the board half of this editor (`+Board.swift`) can
    /// call it.
    ///
    /// **Filling the last slot appends a bar** rather than wrapping the cursor back to slot 1 (device
    /// feedback 2026-07-29). Nothing on the board tells you you've reached the end of the run, so the
    /// wrap silently overwrote the notes you'd just tapped — the drill quietly stayed the same length
    /// while your run got shorter. Growing is the recoverable direction: an unwanted empty bar is
    /// visible in the strip and one tap of the stepper away, where an overwritten note is gone.
    ///
    /// The growth happens **inside the same `mutate`** as the placement, so both are one undo step —
    /// taking back the note takes back the bar it grew. A stronger haptic marks the new bar. At
    /// `maxBars` the cursor holds on the final slot instead of wrapping: still no silent overwrite,
    /// and the stuck cursor reads as "this run is full".
    func placeOrClear(_ cell: FretNote?) {
        if let cell, drill.note(at: selectedSlot) != cell {
            let advance = DrillPlacement.advance(fromSlot: selectedSlot,
                                                 slotCount: drill.notes.count,
                                                 barCount: barCount, maxBars: Self.maxBars)
            mutate {
                let placed = $0.replacingNote(at: selectedSlot, with: cell)
                guard let bars = advance.growToBars else { return placed }
                return placed.withBarCount(bars, beatsPerBar: beatsPerBar)
            }
            selectedSlot = min(advance.cursor, max(0, drill.notes.count - 1))
            haptic(advance.growToBars == nil ? .light : .medium)
        } else {
            mutate { $0.replacingNote(at: selectedSlot, with: nil) }
            haptic(.light)
        }
    }

    /// Apply a pure edit, snapshotting the prior drill onto the undo stack first — but only when the edit
    /// changes something (a no-op tap leaves no dead undo step). The guide isn't captured, so undo never
    /// disturbs it.
    private func mutate(_ transform: (FretboardDrill) -> FretboardDrill) {
        let before = drill
        let after = transform(before)
        guard after != before else { return }
        history.append(before)
        if history.count > Self.maxHistory { history.removeFirst(history.count - Self.maxHistory) }
        drill = after
    }

    /// Step back one edit — pop the last snapshot, then **move the cursor to the slot that changed**
    /// (2026-07-28). Placing a note auto-advances, so an undo used to restore the note while leaving the
    /// cursor a box to its right, and the next tap landed in the wrong slot. Selecting the changed slot
    /// puts it back where the eye already is, which for the common case (undo the last placement) is the
    /// box to the left. Falls back to clamping when the edit changed the grid rather than one note.
    private func undo() {
        guard let previous = history.popLast() else { return }
        let changed = firstDifferingSlot(from: drill, to: previous)
        drill = previous
        selectedSlot = min(changed ?? selectedSlot, max(0, drill.notes.count - 1))
        haptic(.light)
    }

    /// The first slot whose note differs between two drills, or `nil` when they're the same length and
    /// content or the change was structural (a re-grid / bar count change moves every slot).
    private func firstDifferingSlot(from current: FretboardDrill, to restored: FretboardDrill) -> Int? {
        guard current.notes.count == restored.notes.count else { return nil }
        return current.notes.indices.first { current.notes[$0] != restored.notes[$0] }
    }

    /// Wipe every placed note via `cleared()` — grid, subdivision, and guide stay put — and reset the
    /// cursor. Undoable.
    private func clearTaps() {
        mutate { $0.cleared() }
        selectedSlot = 0
        haptic(.medium)
    }

    private func slotAccessibility(_ note: FretNote?) -> String {
        guard let note else { return "rest" }
        let name = FretboardGrid.stringName(note.string, of: drill.stringCount)
        return note.fret == 0 ? "\(name) open" : "\(name) fret \(note.fret)"
    }
}

// MARK: - Undo / clear controls

private extension FretboardDrillEditor {
    /// **Undo** the last tap, **Clear** every placed note, and set the selected slot to a **Rest**. Undo
    /// and Clear leave a scale guide untouched (it isn't in the undo snapshot). Undo disables on an empty
    /// history; Clear disables on an empty board.
    ///
    /// Undo wears the **⌫ backspace glyph** rather than the u-turn arrow (2026-07-28): what it does here
    /// is take back the last thing you typed onto the board, and the finger-pattern field above already
    /// uses `delete.left` for exactly that gesture. The u-turn read as "revert everything".
    var editControls: some View {
        HStack(spacing: 20) {
            Button { undo() } label: { Label("Undo", systemImage: "delete.left") }
                .disabled(history.isEmpty)
            Button(role: .destructive) { clearTaps() } label: {
                Label("Clear taps", systemImage: "xmark.circle")
            }
            .disabled(drill.hasNoNotes)
            Spacer()
            Button("Rest") { placeOrClear(nil) }
        }
        .font(.futura(.caption, weight: .semibold))
        .buttonStyle(.borderless)
        .tint(PocketColor.practice)
    }
}
