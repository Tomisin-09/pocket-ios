import SwiftUI

/// One piece on the board, or the part of it that falls in one row (ADR 0232 D4). It draws **what the
/// loop holds, not a status**: a dashed frame for a loop with no piece, a dot for every tap, and the
/// piece's line as the Journal says it. No badge, no tier, no colour for "done"; the lane colour is the
/// layer's.
///
/// **Tap for its tab, hold to work on it** (D2): the hold is a context menu, the system's own long press,
/// so it never fires the tap as well (a hand-rolled hold on a `Button` does).
struct SongMapPieceView: View {
    let piece: SongMap.Piece
    let placement: SongMap.Placement
    /// The live loop, for its note spelling and the modes it can open in.
    let loop: Loop?
    let width: CGFloat
    let height: CGFloat
    /// Just reached from a row of the Tab view (D10): drawn heavier, so it's the piece your eye lands on.
    var highlighted = false
    /// While pieces are being picked to put together (D11), whether this one is: a tap then picks it or
    /// lets it go, and there's no hold menu. `nil` otherwise.
    var selected: Bool?
    /// Tap: the loop's tab, or picking it while pieces are being put together.
    let onView: () -> Void
    /// Hold: the piece's menu.
    let menu: SongMapPieceMenu

    /// Narrower than this, a piece shows its frame and dots but no words.
    private static let textWidth: CGFloat = 34

    private var tint: Color { SongMapStyle.tint(piece.layer) }

    var body: some View {
        Button(action: onView) {
            ZStack(alignment: .topLeading) {
                frame
                if width >= Self.textWidth {
                    words.padding(.leading, 5).padding(.trailing, selected == nil ? 5 : 20).padding(.top, 3)
                }
                dots
                if let selected, width >= Self.textWidth { tick(selected) }
            }
            .frame(width: width, height: height, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu { if selected == nil { menu } }
        .accessibilityLabel("\(piece.name), \(SongMapStyle.name(piece.layer).lowercased())")
        .accessibilityValue(spokenContent)
        .accessibilityHint(selected == nil ? "Opens its tab" : "Picks it to put together, or lets it go")
        .accessibilityAddTraits(selected == true ? .isSelected : [])
    }

    /// Picked or not, in the corner, while pieces are being put together (D11).
    private func tick(_ isOn: Bool) -> some View {
        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isOn ? tint : PocketColor.textSecondary)
            .background(Circle().fill(PocketColor.background).padding(1))
            .frame(width: width - 4, height: height - 4, alignment: .topTrailing)
            .accessibilityHidden(true)
    }

    /// Drawn heavier when reached from the tab, or picked to put together.
    private var emphasised: Bool { highlighted || selected == true }

    // MARK: - Drawing

    private var shape: UnevenRoundedRectangle {
        let radius: CGFloat = 6
        return UnevenRoundedRectangle(topLeadingRadius: placement.continuesBefore ? 0 : radius,
                                      bottomLeadingRadius: placement.continuesBefore ? 0 : radius,
                                      bottomTrailingRadius: placement.continuesAfter ? 0 : radius,
                                      topTrailingRadius: placement.continuesAfter ? 0 : radius)
    }

    @ViewBuilder private var frame: some View {
        switch piece.content {
        case .empty:
            shape.stroke(tint, style: StrokeStyle(lineWidth: emphasised ? 3 : 1.5, dash: [4, 3]))
        case .handTagged, .piece:
            shape.fill(tint.opacity(emphasised ? 0.34 : 0.16))
                .overlay(shape.stroke(tint, lineWidth: emphasised ? 3 : 1.5))
        }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(piece.name)
                .font(.futura(.caption2, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            if let line { Text(line).font(.futura(.caption2)).foregroundStyle(PocketColor.textSecondary) }
        }
        .lineLimit(1)
    }

    /// A dot at every tap in this part, along the bottom edge.
    private var dots: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(placement.taps.enumerated()), id: \.offset) { _, tap in
                Circle()
                    .fill(tint)
                    .frame(width: 4, height: 4)
                    .offset(x: dotX(tap) - 2, y: height - 8)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private func dotX(_ tap: TimeInterval) -> CGFloat {
        let span = placement.end - placement.start
        guard span > 0 else { return 0 }
        let inset: CGFloat = 4
        return inset + CGFloat((tap - placement.start) / span) * max(width - inset * 2, 0)
    }

    // MARK: - Words

    /// The piece's line, as the Journal says it (ADR 0229), or 🧩 for a loop tagged by hand.
    private var line: String? {
        switch piece.content {
        case .empty: return nil
        case .handTagged: return EntryKind.transcribed.emoji
        case .piece(let transcription):
            return transcription.summary(spelling: loop.map(CountTheNotesModel.spelling(for:))
                                         ?? AppSettings.accidentalPreference)
        }
    }

    private var spokenContent: String {
        switch piece.content {
        case .empty: return "Not worked out yet"
        case .handTagged: return "Tagged transcribed in a note"
        case .piece: return line ?? "Counted"
        }
    }
}

/// A piece's hold menu (ADR 0232 D2), on the piece and on its repeats alike: *View tab*, the modes it can
/// open in, how far it repeats (D14, D15), *Copy to…* once it holds a counted piece (D16), and *Put it
/// together…* (D11).
struct SongMapPieceMenu: View {
    let modes: [LoopRunMode]
    let repeats: SongMapRepeatOptions?
    /// *Copy to…*, or `nil` for a loop with nothing counted to copy.
    let onCopy: (() -> Void)?
    /// *Put it together…* (D11): pick this piece and others to make a routine of.
    let onPutTogether: () -> Void
    let onView: () -> Void
    let onOpen: (LoopRunMode) -> Void

    var body: some View {
        Button(action: onView) { Label("View tab", systemImage: "music.note.list") }
        ForEach(modes) { mode in
            Button { onOpen(mode) } label: { Label(mode.label, systemImage: mode.symbolName) }
        }
        Divider()
        if let repeats { repeatItems(repeats) }
        if let onCopy {
            Button(action: onCopy) { Label("Copy to…", systemImage: "square.on.square") }
        }
        Button(action: onPutTogether) { Label("Put it together…", systemImage: "square.stack.3d.up") }
    }

    /// One item when there's one way to repeat, else a menu of them. Buttons, not a `Toggle` or a `Picker`:
    /// a `Binding` wants a `@Sendable` setter, and this one writes the model. The checkmark says which is
    /// on, as a menu's toggle would.
    @ViewBuilder private func repeatItems(_ repeats: SongMapRepeatOptions) -> some View {
        if repeats.usesMenu {
            Menu {
                Button { repeats.set(nil) } label: { checked("Doesn't repeat", repeats.current == nil) }
                ForEach(repeats.choices, id: \.to) { choice in
                    Button { repeats.set(choice.to) } label: {
                        checked(choice.title, repeats.current == choice.to)
                    }
                }
            } label: {
                Label("Repeats", systemImage: "repeat")
            }
        } else {
            Button { repeats.set(repeats.current == nil ? repeats.choices.first?.to ?? .sectionEnd : nil) } label: {
                Label(repeats.title, systemImage: repeats.current == nil ? "repeat" : "checkmark")
            }
        }
    }

    @ViewBuilder private func checked(_ title: String, _ isOn: Bool) -> some View {
        if isOn { Label(title, systemImage: "checkmark") } else { Text(title) }
    }
}

/// How far a piece repeats (D14, D15): one progression, worked out once, that the song plays over and
/// over. The player's word, never detected, and drawn as a band, never as copies.
struct SongMapRepeatOptions {
    /// Where its repeats can run to, nearest first.
    let choices: [SongMap.RepeatChoice]
    /// How far it repeats now, or `nil` when it doesn't.
    let current: SongMap.RepeatsTo?
    /// The item's title when there's one way to repeat: *Repeats to the end of the section*.
    let title: String
    let set: (SongMap.RepeatsTo?) -> Void

    /// More than one way to repeat, or one that isn't the way it's set to: a single ticked item would then
    /// claim a reach it isn't drawn with.
    var usesMenu: Bool {
        guard let current, !choices.isEmpty else { return choices.count > 1 }
        return choices.count > 1 || !choices.contains { $0.to == current }
    }

    /// Offered when there's room after the piece for it to repeat, and always once it's on, so it can be
    /// switched off again wherever the section's edge has moved to.
    init?(piece: SongMap.Piece, in map: SongMap, set: @escaping (UUID, SongMap.RepeatsTo?) -> Void) {
        let choices = map.repeatChoices(for: piece)
        guard !choices.isEmpty || piece.repeatsDeclared else { return nil }
        self.choices = choices
        current = piece.repeatsDeclared ? piece.repeatsTo : nil
        title = choices.first?.phrase
            ?? (map.hasSections ? "Repeats to the end of the section" : "Repeats to the end of the song")
        let uid = piece.uid
        self.set = { set(uid, $0) }
    }
}
