import SwiftUI

/// The **placement neck** for `FretboardDrillEditor` — split into its own file so the editor stays
/// under the file-length ceiling, alongside `+Guide.swift`. Draws a horizontally-scrollable board of
/// frets 0…`maxFret` with the drill's placed notes on it, and maps a tap on a cell to `placeOrClear`.
/// Holds no state of its own: everything it reads (`selectedSlot`, `pulsingCell`, the guide) lives on
/// the editor, so the strip above and the board here stay one surface rather than two.
extension FretboardDrillEditor {
    /// Pinned string labels on the left, then the scrollable board so any hand position is reachable
    /// without paging a window. Selecting a placed slot scrolls its fret into view via the
    /// `ScrollViewReader` (keyed on the fret-number row) and pulses the dot it landed on.
    var board: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(spacing: 4) {
                ForEach(0..<drill.stringCount, id: \.self) { row in
                    Text(FretboardGrid.stringName(row, of: drill.stringCount))
                        .font(.futura(.caption2, weight: .semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                        .frame(height: 30)
                }
                Color.clear.frame(width: 1, height: 26)   // aligns labels against the inlay + number rows
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
                        inlayRow
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

    // MARK: - Cells

    func boardCell(string: Int, fret: Int) -> some View {
        let cell = FretNote(string: string, fret: fret)
        let isSelected = drill.note(at: selectedSlot) == cell
        let uses = usageCount(of: cell)
        // Resolve in the drill's own tuning so the guide overlay ghosts a scale's notes on the right
        // frets for bass, not guitar's (ADR 0116 S5). Scale pitch classes are tuning-independent.
        let pitchClass = drill.pitchClass(of: cell)
        let inGuide = referenceActive && referencePitchClasses.contains(pitchClass)
        let isGuideRoot = inGuide && pitchClass == referenceRoot
        let isPulsing = pulsingCell == cell
        return Button {
            placeOrClear(cell)
        } label: {
            Circle()
                .fill(fill(isSelected: isSelected, isUsed: uses > 0,
                           inGuide: inGuide, isGuideRoot: isGuideRoot))
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(strokeColor(isSelected: isSelected, isGuideRoot: isGuideRoot),
                                         lineWidth: isGuideRoot ? 1.5 : 1))
                .scaleEffect(isPulsing ? 1.35 : 1)
                .animation(.spring(duration: 0.3, bounce: 0.45), value: isPulsing)
                .frame(width: 30, height: 30)
                .overlay(alignment: .topTrailing) { countPip(uses) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(FretboardGrid.stringName(string, of: drill.stringCount)) "
                            + (fret == 0 ? "open" : "fret \(fret)")
                            + (inGuide ? ", in guide" : ""))
        .accessibilityValue(uses > 1 ? "used at \(uses) steps" : "")
        .accessibilityHint(isSelected ? "Placed here — tap to clear" : "Tap to place")
    }

    /// How many of the drill's slots place this exact note. Drives the count pip below.
    func usageCount(of cell: FretNote) -> Int {
        drill.notes.reduce(0) { $0 + ($1 == cell ? 1 : 0) }
    }

    /// A small **count pip** on a dot the run hits more than once (2026-07-28). Drawn *outside* the
    /// circle rather than inside it, so the dots themselves stay the size they are — the alternative
    /// on the table was numbering every dot, which needed bigger dots and lost to the 24-fret neck.
    @ViewBuilder
    func countPip(_ uses: Int) -> some View {
        if uses > 1 {
            Text("\(uses)")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(PocketColor.background)
                .frame(width: 13, height: 13)
                .background(Circle().fill(PocketColor.textPrimary.opacity(0.75)))
                .offset(x: 2, y: -1)
                .accessibilityHidden(true)
        }
    }

    /// Cell colour by role (T10): selected slot in the tint, notes used by other slots a faint ink,
    /// empty cells near-clear. With the guide on, a cell in the ghosted scale is faintly tinted and its
    /// **root** stronger still, while everything *outside* the scale fades back further than it does with
    /// the guide off — the shape is what you're tracing, so the non-tones should recede rather than sit
    /// at the same weight as the tones (2026-07-28). A tracing aid throughout: nothing snaps.
    func fill(isSelected: Bool, isUsed: Bool, inGuide: Bool, isGuideRoot: Bool) -> Color {
        if isSelected { return tint }
        if isUsed { return PocketColor.textPrimary.opacity(0.18) }
        if isGuideRoot { return PocketColor.marker.opacity(0.55) }
        if inGuide { return tint.opacity(0.28) }
        return PocketColor.surfaceSubtle.opacity(referenceActive ? 0.18 : 0.5)
    }

    /// The cell's outline. A guide root keeps the amber `marker` ring the running board gives roots
    /// (`FretboardGrid.rootRing`), so the tonic reads the same in authoring as in practice; the selected
    /// cell drops its outline because its fill already carries the tint.
    func strokeColor(isSelected: Bool, isGuideRoot: Bool) -> Color {
        if isSelected { return .clear }
        if isGuideRoot { return PocketColor.marker }
        return PocketColor.surfaceBorder.opacity(referenceActive ? 0.5 : 1)
    }

    // MARK: - Rulers

    /// Neck inlays under the board — the same frets a real neck marks, read from `FretboardGrid` so the
    /// authoring board and the practice board can't drift apart. Earns its keep at 24 frets, where
    /// counting fret lines from the nut stops being viable.
    var inlayRow: some View {
        HStack(spacing: 4) {
            ForEach(0...Self.maxFret, id: \.self) { fret in
                Group {
                    if FretboardGrid.doubleInlayFrets.contains(fret) {
                        HStack(spacing: 3) { inlayDot; inlayDot }
                    } else if FretboardGrid.singleInlayFrets.contains(fret) {
                        inlayDot
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 30, height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private var inlayDot: some View {
        Circle().fill(PocketColor.gridLine).frame(width: 5, height: 5)
    }

    /// The fret-number ruler under the board — one label per fret across the full neck. Each carries its
    /// fret as a scroll `.id` so the `ScrollViewReader` can bring a selected note's fret into view.
    var fretNumbers: some View {
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
}
