import SwiftData
import SwiftUI

// **Snags on the piece** (ADR 0234 D7): a place the player is stuck, marked by **holding a note** in the
// strip, with a line they can leave on it for when they come back. A snag is the same mark the practice
// screen makes while playing (ADR 0200), a point on the song, so each shows in both places: a note snagged
// here is a crimson tick on the waveform, and a stumble snagged while playing sits on the note it caught
// on. Snags are saved as they're made, like the practice screen's: not held for Done, not dropped by
// Cancel, and not in ↶ ↷, which is for naming. Split out for file length.
extension NameTheNotesSheet {

    /// The song's snags inside the loop, placed on this visit's taps.
    var pieceSnags: [PieceSnag] { loop.snags(onTaps: taps.map(\.seconds)) }

    /// A hold on a chip: snag that note, or take its snags off, and go to it without playing it, so its
    /// line is right there. A snag has no undo toast (ADR 0202 D3); holding again is the way back.
    func toggleSnag(on index: Int) {
        guard taps.indices.contains(index), let song = loop.song else { return }
        let here = pieceSnags.filter { $0.note == index }.map(\.snag)
        if here.isEmpty {
            let snag = Snag(seconds: taps[index].seconds, loopUID: loop.uid, markedWhileNaming: true)
            modelContext.insert(snag)
            snag.song = song
            haptic(.medium)
        } else {
            // Its line stays in the Journal as an ordinary note on the loop (`JournalEntry.snagUID`).
            for snag in here { modelContext.delete(snag) }
            haptic(.light)
        }
        try? modelContext.save()
        lineDraft = nil
        if index != active { moveTo(index) }
    }

    /// Under the strip: the current note's snag and its line, else where the piece's snags are, else how
    /// to make one, since a hold can't be seen.
    @ViewBuilder var snagLine: some View {
        let placed = pieceSnags
        if let snag = placed.first(where: { $0.note == active })?.snag {
            snagHere(snag)
        } else if !placed.compactMap(\.note).isEmpty {
            let notes = Array(Set(placed.compactMap(\.note))).sorted()
            HStack(spacing: 8) {
                snagGlyph
                hint("\(notes.count) snag\(notes.count == 1 ? "" : "s") on this piece, at "
                     + Self.listed(notes.map { "\($0 + 1)" }))
                Spacer(minLength: 4)
                link("Next snag") { moveTo(notes.first { $0 > active } ?? notes[0]) }
                    .accessibilityIdentifier("naming.nextSnag")
            }
        } else {
            HStack(spacing: 8) {
                snagGlyph.opacity(0.5)
                hint("Hold a \(noun) to snag it, for a place you’re stuck.")
            }
        }
    }

    /// The snag on the note being named: whose it is, its line, and the way to write or change it.
    @ViewBuilder private func snagHere(_ snag: Snag) -> some View {
        let line = loop.line(forSnag: snag.uid)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                snagGlyph
                Text(snag.markedWhileNaming == true ? "\(noun.capitalized) \(active + 1) snagged"
                     : "Snagged while playing")
                    .font(.futura(.caption, weight: .semibold))
                Spacer(minLength: 4)
                if lineDraft == nil {
                    link(line == nil ? "Add a line" : "Edit line") { lineDraft = line?.text ?? "" }
                        .accessibilityIdentifier("naming.snagLine")
                }
            }
            if let lineDraft {
                lineEditor(lineDraft, snag: snag, line: line)
            } else if let line {
                Text(line.text)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// One line, straight to the loop's Journal when saved (not held for Done), tied to the snag.
    private func lineEditor(_ draft: String, snag: Snag, line: JournalEntry?) -> some View {
        let text = Binding { lineDraft ?? "" } set: { lineDraft = $0 }
        return VStack(alignment: .leading, spacing: 6) {
            TextField("What’s stopping you here?", text: text)
                .font(.futura(.footnote))
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit { saveLine(draft: lineDraft ?? draft, snag: snag, line: line) }
                .accessibilityIdentifier("naming.snagLineField")
            HStack(spacing: 18) {
                link("Save") { saveLine(draft: lineDraft ?? draft, snag: snag, line: line) }
                link("Cancel") { lineDraft = nil }
                Spacer(minLength: 0)
                hint("Saves to the Journal now.")
            }
        }
    }

    private func saveLine(draft: String, snag: Snag, line: JournalEntry?) {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if let line {
            if trimmed.isEmpty {
                JournalWriter.delete(line, from: modelContext)
            } else {
                JournalWriter.update(line, text: trimmed, kind: line.kind)
            }
        } else {
            // 👂, never 🧩: the song map reads a 🧩 note as the loop solved by hand, and a stuck note is the
            // opposite (ADR 0234 D7).
            JournalWriter.add(to: .loop(loop), text: trimmed, kind: .ear, snagUID: snag.uid, into: modelContext)
        }
        try? modelContext.save()
        lineDraft = nil
    }

    var snagGlyph: some View {
        SnagCatch()
            .stroke(PocketColor.oracle, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .frame(width: 18, height: 18)
            .accessibilityHidden(true)
    }

    /// "9", "9 and 12", "3, 9 and 12".
    nonisolated static func listed(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + (items.last ?? "")
    }
}
