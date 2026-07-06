import SwiftUI

/// The **fretboard template's authoring editor** (ADR 0065 build 2 — the per-kind payload editor the
/// ADR defers and slices). The "steps lane + tap-to-place" model: a segmented control sets the
/// subdivision, a **slot strip** shows the bar's note slots (tap to select one), and an interactive
/// **fretboard** places a note into the selected slot (tap advances to the next slot; tapping a slot's
/// own note clears it to a rest). A fret-**position** control scrolls the visible window up the neck,
/// so a drill can sit anywhere — the "span across the fretboard" the notes occupy follows what you
/// place, and the playback window derives from it.
///
/// A thin skin over `FretboardDrill`'s pure ops (`replacingNote`, `resized`) — the view maps taps to
/// those and draws the result, holding no timing logic of its own (T5). **T10** — every colour is a
/// semantic `PocketColor` role, so the editor reskins under light/dark and any future theme.
///
/// A `FretboardDrillPreview` sits above the placement board — the board shows *where* notes are
/// placed, the preview shows *when* they'd sound, so "watch it before you save" works for a
/// hand-placed drill too, not just the generative editors.
struct FretboardDrillEditor: View {
    /// Beats per bar (the exercise's meter) — fixes how many slots each subdivision produces.
    let beatsPerBar: Int
    @Binding var drill: FretboardDrill
    var tint: Color = PocketColor.practice

    /// The slot the next placed note lands in — highlighted in the strip and reflected on the board.
    @State private var selectedSlot = 0
    /// The lowest fret the board window shows; `0` includes the open string. Scrolled by the position
    /// control so notes anywhere on the neck can be authored.
    @State private var lowestVisibleFret = 1
    /// The global note-caption preference — shown on the preview strip above (not on the placement
    /// board below, which stays focused on *where*, not *what*). Shared with every other fretboard
    /// editor and the live practice run (ADR 0065 T10).
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }
    /// A one-shot "watch it" request (ADR 0065) — set by `FretboardPlayOnceButton`, read by the
    /// preview below. The walking-highlight preference itself lives only in Settings ("Animate
    /// exercises") now; Watch covers "see it move once" here without a redundant local toggle.
    @State private var playOnceToken: Date?

    /// The subdivisions the segmented control offers, mapped to notes-per-beat.
    private static let resolutions: [(perBeat: Int, label: String)] =
        [(1, "Quarters"), (2, "Eighths"), (3, "Triplets"), (4, "Sixteenths")]
    private static let visibleFretCount = 5
    private static let maxLowestFret = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            displayOptionsControl
            FretboardDrillPreview(drill: drill, tint: tint, labelMode: labelMode,
                                  playOnceToken: playOnceToken)
            resolutionPicker
            slotStrip
            board
            positionControls
            Text("Pick a slot, then tap a fret to place a note. Tap a placed note to clear it.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    // MARK: - Display options (labels, global preference)

    /// A compact menu, top of the editor, holding how notes are captioned plus a watch/sound preview
    /// of the hand-placed drill — the row every other fretboard-family editor carries (ADR 0065).
    /// The walking-highlight preference itself lives only in Settings now, since Watch already
    /// covers "see it move once" here.
    private var displayOptionsControl: some View {
        HStack {
            FretboardPlayOnceButton(playToken: $playOnceToken, tint: tint)
            SoundPreviewButton(drill: drill, tint: tint)
            Spacer()
            Menu {
                Picker("Labels", selection: $storedLabelMode) {
                    ForEach(FretLabelMode.allCases) { mode in
                        Text(mode.pickerLabel).tag(mode.rawValue)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                    Text("Display")
                }
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(tint)
            }
            .accessibilityLabel("Display options: labels \(labelMode.pickerLabel)")
        }
    }

    // MARK: - Subdivision

    private var resolutionPicker: some View {
        Picker("Subdivision", selection: resolutionBinding) {
            ForEach(Self.resolutions, id: \.perBeat) { resolution in
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
                drill = drill.resized(notesPerBeat: newPerBeat, beatsPerBar: beatsPerBar)
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
            if let note { lowestVisibleFret = windowLowest(for: note.fret) }
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

    private var board: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(spacing: 4) {
                ForEach(0..<drill.stringCount, id: \.self) { row in
                    Text(FretboardGrid.stringName(row, of: drill.stringCount))
                        .font(.futura(.caption2, weight: .semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                        .frame(height: 30)
                }
            }
            VStack(spacing: 4) {
                ForEach(0..<drill.stringCount, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<Self.visibleFretCount, id: \.self) { column in
                            boardCell(string: row, fret: lowestVisibleFret + column)
                        }
                    }
                }
                fretNumbers
            }
        }
    }

    private func boardCell(string: Int, fret: Int) -> some View {
        let cell = FretNote(string: string, fret: fret)
        let isSelected = drill.note(at: selectedSlot) == cell
        let isUsed = drill.notes.contains(cell)
        return Button {
            placeOrClear(cell)
        } label: {
            Circle()
                .fill(fill(isSelected: isSelected, isUsed: isUsed))
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(PocketColor.surfaceBorder, lineWidth: isSelected ? 0 : 1))
                .frame(maxWidth: .infinity, minHeight: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(FretboardGrid.stringName(string, of: drill.stringCount)) "
                            + (fret == 0 ? "open" : "fret \(fret)"))
        .accessibilityHint(isSelected ? "Placed here — tap to clear" : "Tap to place")
    }

    /// Cell colour by role (T10): the selected slot's note in the content tint, notes used by other
    /// slots a faint ink so the drill's shape reads, empty cells a near-clear surface.
    private func fill(isSelected: Bool, isUsed: Bool) -> Color {
        if isSelected { return tint }
        if isUsed { return PocketColor.textPrimary.opacity(0.18) }
        return PocketColor.surfaceSubtle.opacity(0.5)
    }

    private var fretNumbers: some View {
        HStack(spacing: 4) {
            ForEach(0..<Self.visibleFretCount, id: \.self) { column in
                Text(lowestVisibleFret + column == 0 ? "0" : "\(lowestVisibleFret + column)")
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary.opacity(0.7))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Position control

    private var positionControls: some View {
        HStack(spacing: 16) {
            Button { moveWindow(-1) } label: { Image(systemName: "chevron.left") }
                .disabled(lowestVisibleFret <= 0)
            Text(windowLabel)
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(minWidth: 96)
            Button { moveWindow(1) } label: { Image(systemName: "chevron.right") }
                .disabled(lowestVisibleFret >= Self.maxLowestFret)
            Spacer()
            Button("Rest") { placeOrClear(nil) }
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
        }
        .tint(PocketColor.practice)
    }

    private var windowLabel: String {
        let highest = lowestVisibleFret + Self.visibleFretCount - 1
        let low = lowestVisibleFret == 0 ? "Open" : "Fret \(lowestVisibleFret)"
        return "\(low)–\(highest)"
    }

    // MARK: - Edits (map a tap to a pure op)

    /// Place `cell` into the selected slot and advance; tapping the slot's own note (or "Rest" with
    /// `nil`) clears it instead. Auto-advance wraps so a run can be tapped in quickly.
    private func placeOrClear(_ cell: FretNote?) {
        if let cell, drill.note(at: selectedSlot) != cell {
            drill = drill.replacingNote(at: selectedSlot, with: cell)
            selectedSlot = (selectedSlot + 1) % max(1, drill.notes.count)
        } else {
            drill = drill.replacingNote(at: selectedSlot, with: nil)
        }
        haptic(.light)
    }

    private func moveWindow(_ delta: Int) {
        lowestVisibleFret = min(Self.maxLowestFret, max(0, lowestVisibleFret + delta))
        haptic(.light)
    }

    /// The window low that keeps `fret` comfortably in view when a slot is selected.
    private func windowLowest(for fret: Int) -> Int {
        guard fret > 0 else { return 0 }
        let clamped = min(Self.maxLowestFret, max(1, fret - 1))
        return clamped
    }

    private func slotAccessibility(_ note: FretNote?) -> String {
        guard let note else { return "rest" }
        let name = FretboardGrid.stringName(note.string, of: drill.stringCount)
        return note.fret == 0 ? "\(name) open" : "\(name) fret \(note.fret)"
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
