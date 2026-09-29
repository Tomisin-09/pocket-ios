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
    /// Tap: the loop's tab.
    let onView: () -> Void
    /// A mode picked from the hold menu.
    let onOpen: (LoopRunMode) -> Void
    /// The hold menu's *Repeats to the end of the section* (D14), or `nil` where it isn't offered.
    var repeats: SongMapRepeatToggle?

    /// Narrower than this, a piece shows its frame and dots but no words.
    private static let textWidth: CGFloat = 34

    private var tint: Color { SongMapStyle.tint(piece.layer) }
    private var modes: [LoopRunMode] { loop.map(SongMapPieceSheet.modes(for:)) ?? [] }

    var body: some View {
        Button(action: onView) {
            ZStack(alignment: .topLeading) {
                frame
                if width >= Self.textWidth { words.padding(.horizontal, 5).padding(.top, 3) }
                dots
            }
            .frame(width: width, height: height, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            SongMapPieceMenu(modes: modes, repeats: repeats, onView: onView, onOpen: onOpen)
        }
        .accessibilityLabel("\(piece.name), \(SongMapStyle.name(piece.layer).lowercased())")
        .accessibilityValue(spokenContent)
        .accessibilityHint("Opens its tab")
    }

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
            shape.stroke(tint, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        case .handTagged, .piece:
            shape.fill(tint.opacity(highlighted ? 0.34 : 0.16))
                .overlay(shape.stroke(tint, lineWidth: highlighted ? 3 : 1.5))
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
/// open in, and, when there's room after it, *Repeats to the end of the section* (D14).
struct SongMapPieceMenu: View {
    let modes: [LoopRunMode]
    let repeats: SongMapRepeatToggle?
    let onView: () -> Void
    let onOpen: (LoopRunMode) -> Void

    var body: some View {
        Button(action: onView) { Label("View tab", systemImage: "music.note.list") }
        ForEach(modes) { mode in
            Button { onOpen(mode) } label: { Label(mode.label, systemImage: mode.symbolName) }
        }
        if let repeats {
            Divider()
            // A button, not a `Toggle`: a `Binding` wants a `@Sendable` setter, and this one writes the model.
            // The checkmark says it's on, as a menu's toggle would.
            Button { repeats.set(!repeats.isOn) } label: {
                Label(repeats.title, systemImage: repeats.isOn ? "checkmark" : "repeat")
            }
        }
    }
}

/// *Repeats to the end of the section* (D14): one progression, worked out once, that the section plays
/// over and over. The player's word, never detected, and drawn as a label, never as copies.
struct SongMapRepeatToggle {
    let isOn: Bool
    /// *…of the section*, or *…of the song* when it has none.
    let title: String
    let set: (Bool) -> Void

    /// Offered when there's room after the piece for it to repeat, and always once it's on, so it can be
    /// switched off again wherever the section's edge has moved to.
    init?(piece: SongMap.Piece, inSections: Bool, set: @escaping (UUID, Bool) -> Void) {
        guard piece.canRepeat || piece.repeatsDeclared else { return nil }
        isOn = piece.repeatsDeclared
        title = inSections ? "Repeats to the end of the section" : "Repeats to the end of the song"
        let uid = piece.uid
        self.set = { set(uid, $0) }
    }
}
