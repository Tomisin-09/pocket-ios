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
    @State private var selectedSlot = 0
    /// The fret the horizontally-scrollable neck should scroll into view — set when a placed slot is
    /// selected so its note comes into view, consumed by the board's `ScrollViewReader`.
    @State private var scrollTargetFret: Int?
    /// The global note-caption preference — shown on the preview strip above (not on the placement
    /// board below, which stays focused on *where*, not *what*). Shared with every other fretboard
    /// editor and the live practice run (ADR 0065 T10).
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }
    /// A one-shot "watch it" request (ADR 0065) — set by `FretboardPlayOnceButton`, read by the
    /// preview below. The walking-highlight preference itself lives only in Settings ("Animate
    /// exercises") now; Watch covers "see it move once" here without a redundant local toggle.
    @State private var playOnceToken: Date?
    /// The scale being ghosted as a tracing guide (`nil` = off), and its key (root pitch class). Only
    /// consulted when `referenceEnabled` — the guide overlay on the placement board. Non-private so the
    /// guide controls in `FretboardDrillEditor+Guide.swift` can bind them (same-module split).
    @State var referenceScale: ScaleReference?
    @State var referenceRoot = 0   // C
    /// Undo stack of drill snapshots — one per note edit, so **Undo** steps back a tap and **Clear** is
    /// reversible (2026-07-23). Holds only the *drill*, never the guide; capped to stay bounded.
    @State private var history: [FretboardDrill] = []
    private static let maxHistory = 100

    /// Whether the guide is on and a scale is chosen.
    private var referenceActive: Bool { referenceEnabled && referenceScale != nil }
    /// The pitch classes the guide ghosts, for the chosen scale + key.
    private var referencePitchClasses: Set<Int> {
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
    private static let maxFret = 15
    /// Ceiling on the Bars stepper — a custom drill can span up to this many bars of the exercise meter.
    private static let maxBars = 8
    private var barCount: Int { drill.barCount(beatsPerBar: beatsPerBar) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FretboardDisplayOptionsBar(heardNotes: heardNotes, secondsPerNote: secondsPerNote,
                                       playToken: $playOnceToken, tint: tint)
            FretboardDrillPreview(drill: drill, tint: tint, labelMode: labelMode,
                                  playOnceToken: playOnceToken)
            resolutionPicker
            barsStepper
            slotStrip
            if referenceEnabled { guideControls }
            board
            editControls
            Text("Pick a slot, then tap a fret to place a note. Tap a placed note to clear it. "
                 + "Swipe the neck to reach any fret; add bars for a longer run.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .hearStopsOnDisappear()
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

    /// The bar's slots, grouped by beat and wrapping to new rows (`FlowLayout`) so a denser grid grows
    /// down rather than off-screen — the same layout the strum editor uses.
    private var slotStrip: some View {
        FlowLayout(spacing: 12) {
            ForEach(Array(beatGroups.enumerated()), id: \.offset) { _, group in
                HStack(spacing: 5) {
                    ForEach(group, id: \.self) { index in slotCell(index) }
                }
            }
        }
    }

    private var beatGroups: [[Int]] {
        let perBeat = max(1, drill.notesPerBeat)
        return stride(from: 0, to: drill.notes.count, by: perBeat).map { start in
            Array(start..<min(start + perBeat, drill.notes.count))
        }
    }

    private func slotCell(_ index: Int) -> some View {
        let note = drill.notes.indices.contains(index) ? drill.notes[index] : nil
        let isSelected = index == selectedSlot
        return Button {
            selectedSlot = index
            if let note { scrollTargetFret = note.fret }
            haptic(.light)
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

    // MARK: - Fretboard

    /// The placement neck: pinned string labels on the left, then a **horizontally-scrollable** full
    /// board (frets 0…`maxFret`) so any hand position is reachable without paging a window. Selecting a
    /// placed slot scrolls its fret into view via the `ScrollViewReader` (keyed on the fret-number row).
    private var board: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(spacing: 4) {
                ForEach(0..<drill.stringCount, id: \.self) { row in
                    Text(FretboardGrid.stringName(row, of: drill.stringCount))
                        .font(.futura(.caption2, weight: .semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                        .frame(height: 30)
                }
                Color.clear.frame(width: 1, height: 14)   // aligns labels against the fret-number row
            }
            .frame(width: 16)   // fixed gutter — matches FretboardGrid so the two boards line up
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(0..<drill.stringCount, id: \.self) { row in
                            HStack(spacing: 4) {
                                ForEach(0...Self.maxFret, id: \.self) { fret in
                                    boardCell(string: row, fret: fret)
                                }
                            }
                        }
                        fretNumbers
                    }
                }
                .onChange(of: scrollTargetFret) { _, fret in
                    guard let fret else { return }
                    withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(fret, anchor: .center) }
                }
            }
        }
    }

    private func boardCell(string: Int, fret: Int) -> some View {
        let cell = FretNote(string: string, fret: fret)
        let isSelected = drill.note(at: selectedSlot) == cell
        let isUsed = drill.notes.contains(cell)
        // Resolve in the drill's own tuning so the guide overlay ghosts a scale's notes on the right
        // frets for bass, not guitar's (ADR 0116 S5). Scale pitch classes are tuning-independent.
        let pitchClass = drill.pitchClass(of: cell)
        let inGuide = referenceActive && referencePitchClasses.contains(pitchClass)
        let isGuideRoot = inGuide && pitchClass == referenceRoot
        return Button {
            placeOrClear(cell)
        } label: {
            Circle()
                .fill(fill(isSelected: isSelected, isUsed: isUsed,
                           inGuide: inGuide, isGuideRoot: isGuideRoot))
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(PocketColor.surfaceBorder, lineWidth: isSelected ? 0 : 1))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(FretboardGrid.stringName(string, of: drill.stringCount)) "
                            + (fret == 0 ? "open" : "fret \(fret)")
                            + (inGuide ? ", in guide" : ""))
        .accessibilityHint(isSelected ? "Placed here — tap to clear" : "Tap to place")
    }

    /// Cell colour by role (T10): selected slot in the tint, notes used by other slots a faint ink,
    /// empty cells near-clear. With the guide on, a cell in the ghosted scale is faintly tinted (its
    /// **root** stronger) so the shape reads through the board — a tracing aid, no snapping.
    private func fill(isSelected: Bool, isUsed: Bool, inGuide: Bool, isGuideRoot: Bool) -> Color {
        if isSelected { return tint }
        if isUsed { return PocketColor.textPrimary.opacity(0.18) }
        if isGuideRoot { return tint.opacity(0.45) }
        if inGuide { return tint.opacity(0.20) }
        return PocketColor.surfaceSubtle.opacity(0.5)
    }

    /// The fret-number ruler under the board — one label per fret across the full neck. Each carries its
    /// fret as a scroll `.id` so the `ScrollViewReader` can bring a selected note's fret into view.
    private var fretNumbers: some View {
        HStack(spacing: 4) {
            ForEach(0...Self.maxFret, id: \.self) { fret in
                Text("\(fret)")
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary.opacity(0.7))
                    .frame(width: 30)
                    .id(fret)
            }
        }
    }

    // MARK: - Edits (map a tap to a pure op)

    /// Place `cell` into the selected slot and advance; tapping the slot's own note (or "Rest" with
    /// `nil`) clears it instead. Auto-advance wraps so a run can be tapped in quickly.
    private func placeOrClear(_ cell: FretNote?) {
        if let cell, drill.note(at: selectedSlot) != cell {
            mutate { $0.replacingNote(at: selectedSlot, with: cell) }
            selectedSlot = (selectedSlot + 1) % max(1, drill.notes.count)
        } else {
            mutate { $0.replacingNote(at: selectedSlot, with: nil) }
        }
        haptic(.light)
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

    /// Step back one edit — pop the last snapshot and keep the selection in range.
    private func undo() {
        guard let previous = history.popLast() else { return }
        drill = previous
        selectedSlot = min(selectedSlot, max(0, drill.notes.count - 1))
        haptic(.light)
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
    var editControls: some View {
        HStack(spacing: 20) {
            Button { undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
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

#Preview("Fretboard editor") {
    struct Harness: View {
        @State private var drill = FretboardDrill.spiderWalk
        var body: some View {
            FretboardDrillEditor(beatsPerBar: 4, drill: $drill)
                .padding()
                .background(PocketColor.background)
        }
    }
    return Harness().preferredColorScheme(.dark)
}
