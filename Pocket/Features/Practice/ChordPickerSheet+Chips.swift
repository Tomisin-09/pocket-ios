import SwiftUI

// MARK: - Root row (ADR 0297)

extension ChordPickerSheet {
    /// **Any**, then the twelve roots. Twelve don't fit across a phone, so the row scrolls and opens on
    /// the chosen root — the same row *Use a progression* gives its keys, so the two read as one control.
    var rootRow: some View {
        HStack(spacing: 10) {
            Text("Root")
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
                // Every chip says "Root C" itself, so the caption would only be read twice.
                .accessibilityHidden(true)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        rootChip(nil)
                        ForEach(0..<12, id: \.self) { rootChip($0) }
                    }
                    .padding(.vertical, 2)
                    .padding(.trailing, 16)
                }
                .onAppear { proxy.scrollTo(Self.rootChipID(root), anchor: .center) }
            }
        }
        .padding(.leading, 16)
        .padding(.bottom, 12)
    }

    /// A string id, never the bare pitch class: an `Int` would collide with the `ForEach`'s own ids.
    nonisolated static func rootChipID(_ pitchClass: Int?) -> String {
        pitchClass.map { "chordPicker.root.\($0)" } ?? "chordPicker.root.any"
    }

    private func rootChip(_ pitchClass: Int?) -> some View {
        let label = pitchClass.map { rootNames[$0] } ?? "Any"
        let isSelected = root == pitchClass
        return Button {
            root = pitchClass
            haptic(.light)
        } label: {
            Text(label)
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(isSelected ? PocketColor.background : PocketColor.textPrimary)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(Capsule().fill(isSelected ? PocketColor.practice : PocketColor.surfaceStandard))
        }
        .buttonStyle(.borderless)
        .id(Self.rootChipID(pitchClass))
        // "Root C", not "C": a bare letter is also a root-menu item and a string name, and a UI test
        // asking for `buttons["C"]` must not land here.
        .accessibilityLabel(pitchClass == nil ? "Any root" : "Root \(label)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier(Self.rootChipID(pitchClass))
    }
}

// MARK: - The swapped chord's chip (ADR 0297)

extension ChordPickerSheet {
    /// Which chip a swap marks as the target it scrolls to. Only one, because a scroll target has to be
    /// unique, and a movable shape wins: it is marked at every root, where a fixed chip is only marked
    /// where it already sits. (An F barre is both the E-shape at F and an open-library chord; both are
    /// marked, and the grip is the one scrolled to.)
    enum CurrentChip { case grip, bass, saved, open }

    var currentChip: CurrentChip? {
        guard let current else { return nil }
        if current.grip != nil { return .grip }
        if current.bassShape != nil { return .bass }
        if filteredSaved.contains(where: { current.isCurrent(frets: $0.voicing.frets) }) { return .saved }
        if filteredOpen.contains(where: { current.isCurrent(frets: $0.frets) }) { return .open }
        return nil
    }
}

private extension View {
    /// The id the insert pane scrolls to, on the one chip that carries it.
    @ViewBuilder
    func pickerScrollTarget(_ isTarget: Bool) -> some View {
        if isTarget { id(ChordPickerSheet.currentChipID) } else { self }
    }
}

// MARK: - Chips

extension ChordPickerSheet {
    func savedChip(_ saved: SavedChord) -> some View {
        let isCurrent = current?.isCurrent(frets: saved.voicing.frets) ?? false
        return fixedChip(voicing: saved.voicing, title: saved.name, saved: true, isCurrent: isCurrent)
            .pickerScrollTarget(isCurrent && currentChip == .saved)
    }

    func openChip(_ voicing: ChordVoicing) -> some View {
        let isCurrent = current?.isCurrent(frets: voicing.frets) ?? false
        return fixedChip(voicing: voicing, title: voicing.name, saved: false, isCurrent: isCurrent)
            .pickerScrollTarget(isCurrent && currentChip == .open)
    }

    private func fixedChip(voicing: ChordVoicing, title: String, saved: Bool,
                           isCurrent: Bool) -> some View {
        Button { insert(voicing) } label: {
            chipBody(voicing: voicing, title: title, subtitle: nil, saved: saved, isCurrent: isCurrent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Insert \(title)")
        .accessibilityValue(isCurrent ? "Current chord" : "")
    }

    /// A movable grip's chip. The subtitle is the shape family ("E-shape barre") at every root; what the
    /// title and picture show depends on the root row (see `gripChip`).
    func movableChip(_ grip: ChordGrip) -> some View {
        let subtitle = ChordPicker.movableSubtitle(grip)
        return gripChip(grip, subtitle: subtitle, placedDescription: subtitle,
                        accessibility: "\(grip.quality.displayName) \(subtitle), choose a root")
    }

    /// A triad grip's chip (ADR 0109) — the same two behaviours as a movable shape; the subtitle is the
    /// string set it voices and its inversion.
    func triadChip(_ grip: ChordGrip) -> some View {
        gripChip(grip, subtitle: ChordPicker.triadSubtitle(grip),
                 placedDescription: "triad on \(grip.name), \(grip.inversionName)",
                 accessibility: "\(grip.quality.displayName) triad on \(grip.name), choose a root")
    }

    /// Any `ChordGrip` chip.
    ///
    /// - **A root chosen** (ADR 0297): the chip *is* the chord the grip makes there — its real name
    ///   ("Cm7") and frets — and a tap inserts it. What you see is what goes in.
    /// - **Any**: the root-agnostic browse picture (`browseVoicing`, a fret-5 barre) labelled with the
    ///   quality, over a menu of the twelve roots (ADR 0103 D4).
    ///
    /// The swapped chord's grip is marked either way — the same shape, wherever it is drawn.
    @ViewBuilder
    func gripChip(_ grip: ChordGrip, subtitle: String, placedDescription: String,
                  accessibility: String) -> some View {
        let isCurrent = current?.grip == grip
        Group {
            if let voicing = placed(grip) {
                Button { insert(voicing) } label: {
                    chipBody(voicing: voicing, title: voicing.name, subtitle: subtitle, saved: false,
                             isCurrent: isCurrent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Insert \(voicing.name), \(placedDescription)")
            } else {
                Menu {
                    ForEach(rootNames.indices, id: \.self) { pitchClass in
                        Button(rootNames[pitchClass]) {
                            insert(grip.voicing(rootPitchClass: pitchClass, spelling: spelling))
                        }
                    }
                } label: {
                    chipBody(voicing: grip.browseVoicing, title: grip.quality.displayName,
                             subtitle: subtitle, saved: false, isCurrent: isCurrent)
                }
                .accessibilityLabel(accessibility)
            }
        }
        .accessibilityValue(isCurrent ? "Current shape" : "")
        .pickerScrollTarget(isCurrent)
    }

    /// A bass shape's chip (ADR 0164) — the same two behaviours as a grip, because a dyad is movable in
    /// exactly the same sense. On **Any** the picture is the shape rooted on the low E at fret 5, where a
    /// hand meets it, over the root menu.
    ///
    /// A root the shape can't reach is **omitted from the menu** rather than offered and silently
    /// dropped — `BassChordShape.voicing` refuses instead of clamping (that's the point of it), so an
    /// unreachable root would otherwise be a button that does nothing. For the same reason a chosen root
    /// the shape can't reach falls back to the menu rather than drawing a chip with nothing to insert.
    @ViewBuilder
    func bassChip(_ shape: BassChordShape) -> some View {
        let isCurrent = current?.bassShape == shape
        Group {
            if let voicing = placedBass(shape) {
                Button { insert(voicing) } label: {
                    chipBody(voicing: voicing, title: voicing.name, subtitle: shape.name, saved: false,
                             isCurrent: isCurrent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Insert \(voicing.name), \(shape.name)")
            } else {
                bassMenuChip(shape, isCurrent: isCurrent)
            }
        }
        .accessibilityValue(isCurrent ? "Current shape" : "")
        .pickerScrollTarget(isCurrent)
    }

    private func bassMenuChip(_ shape: BassChordShape, isCurrent: Bool) -> some View {
        let browse = shape.voicing(rootString: ChordVoicing.bassStringCount - 1, rootFret: 5,
                                   spelling: spelling)
        return Menu {
            ForEach(rootNames.indices, id: \.self) { pitchClass in
                if let voicing = shape.voicing(rootPitchClass: pitchClass, spelling: spelling) {
                    Button(rootNames[pitchClass]) { insert(voicing) }
                }
            }
        } label: {
            chipBody(voicing: browse ?? ChordVoicing(shape.name, frets: [nil, nil, nil, 0]),
                     title: shape.name, subtitle: "bass", saved: false, isCurrent: isCurrent)
        }
        .accessibilityLabel("\(shape.name), choose a root")
    }

    /// The chip's face. The swapped chord's chip carries a heavier border and a check — "this is the one
    /// you have" — and keeps its place in the grid, so the eye finds it where the shape always sits.
    func chipBody(voicing: ChordVoicing, title: String, subtitle: String?, saved: Bool,
                  isCurrent: Bool) -> some View {
        VStack(spacing: 6) {
            ChordDiagramView(voicing: voicing, tint: PocketColor.practice, showsName: false)
                .frame(height: 54)
            Text(title)
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(saved ? PocketColor.practice : PocketColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            // A single reserved line keeps every chip the same height whether or not it has a subtitle.
            Text(subtitle ?? " ")
                .font(.futura(.caption2))
                .foregroundStyle(PocketColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 13).fill(PocketColor.surfaceSubtle))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(
            borderColor(saved: saved, isCurrent: isCurrent), lineWidth: isCurrent ? 2 : 1))
        .overlay(alignment: .topTrailing) {
            if isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PocketColor.practice)
                    .padding(6)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }

    private func borderColor(saved: Bool, isCurrent: Bool) -> Color {
        if isCurrent { return PocketColor.practice }
        return saved ? PocketColor.practice.opacity(0.35) : PocketColor.surfaceBorder
    }
}
