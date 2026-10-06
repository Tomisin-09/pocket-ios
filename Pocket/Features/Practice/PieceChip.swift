import SwiftUI

/// **One tap of a piece as a chip**: its number over what it was named. Name the notes' strip draws a row
/// of them (ADR 0227 D2), and so does the order row under *Watch it on the neck* (ADR 0254), which this was
/// lifted out for. Only the face is here: the strip adds the dashes on the note just placed, a snag's mark
/// and its gestures, and the viewer adds nothing, since its chips are only read.
struct PieceChip: View {
    /// 1-based, as the strip numbers them.
    let number: Int
    /// What it was named (`NamingStrip.chipText`), or `nil` for a tap not named yet, shown as "?".
    let text: String?
    /// Shown dimmed: a name that can't be drawn where it's shown.
    var dim = false
    /// Filled: the chip being named.
    var isCurrent = false

    var body: some View {
        VStack(spacing: 0) {
            Text("\(number)")
                .font(.futura(.caption2))
                .monospacedDigit()
            Text(text ?? "?")
                .font(.futura(.subheadline, weight: text == nil || dim ? nil : .bold))
                .lineLimit(1)
        }
        .foregroundStyle(isCurrent ? PocketColor.background
                         : text == nil || dim ? PocketColor.textSecondary : PocketColor.textPrimary)
        .padding(.horizontal, 8)
        .frame(minWidth: 46, minHeight: 44)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isCurrent ? PocketColor.practice : .clear))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(isCurrent ? .clear : PocketColor.surfaceBorder))
    }

    /// A row of chips fades out at both ends, so a chip cut off by the edge reads as "more this way".
    static var rowFade: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 18)
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 18)
        }
    }
}

extension View {
    /// The ring on the chip being heard while the loop plays: just outside the chip, so it reads on a
    /// filled current chip as well as on the rest.
    func heardRing(_ isHeard: Bool) -> some View {
        overlay {
            if isHeard {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(PocketColor.practice, lineWidth: 2)
                    .padding(-3)
            }
        }
    }
}

extension NamingStrip {
    /// What a chip shows. On the neck (Fret & string, and the viewer) a placed note is its string and fret
    /// ("B8"), and a name given by ear shows dimmed: it can't be drawn there. Off it (By ear) every answer
    /// is its name, a placed note read as the note it sounds (0227 D7).
    nonisolated static func chipText(_ label: PieceLabel?, onTheNeck: Bool, openMidi: [Int],
                                     spelling: NoteSpelling) -> (text: String?, dim: Bool) {
        guard let label else { return (nil, false) }
        if onTheNeck {
            // A chord of four notes or more is too long to spell out on a chip; its name says it.
            if label.frettedNotes.count > 3 { return (label.name(openMidi: openMidi, spelling: spelling), false) }
            if label.isOnTheNeck {
                return (NeckNoteEditor<EmptyView>.fretText(label.frettedNotes, openMidi: openMidi), false)
            }
            return (label.name(openMidi: openMidi, spelling: spelling), true)
        }
        // On By ear a shape that spells no chord shows its interval or notes, dimmed: nothing to name.
        let unread = label.isOnTheNeck && label.earReading(openMidi: openMidi) == nil
        return (label.name(openMidi: openMidi, spelling: spelling), unread)
    }
}
