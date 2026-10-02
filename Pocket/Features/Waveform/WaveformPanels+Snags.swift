import SwiftUI

// The snags panel (ADR 0202 D2) — the marks' one home outside the waveform.
//
// ADR 0200 shipped a mark that could be made and never unmade: a crimson tick appeared on the
// canvas and there was no row, no list and no delete anywhere in the app. A mark you cannot remove
// is not a cheap mark, it is a permanent one, and cheapness is the whole argument for the tap.
//
// It borrows the loops/markers grammar rather than inventing one — a `CollapsiblePanel`, a row you
// tap to go there, a row you hold to open its sheet — with **no multi-select**. A snag has nothing to
// rename, recolour or rate, so the sheet a hold opens holds one thing: a line on it, for when you
// come back (ADR 0238). The marks are made while playing, at one tap; the words come after.

struct SnagsPanel: View {
    let snags: [Snag]
    /// Loop names by `uid`, for the row caption (ADR 0203 D2). A snag whose loop is gone resolves to
    /// nothing and simply shows no name.
    var loopNames: [UUID: String] = [:]
    /// Each snag's line by the snag's `uid` (ADR 0238), drawn under its row.
    var lines: [UUID: String] = [:]
    @Binding var expanded: Bool
    /// Tap the row — seek the playhead there and play.
    let onSeek: (Snag) -> Void
    /// Hold the row — write or change its line (ADR 0238).
    var onEdit: (Snag) -> Void = { _ in }
    /// Remove the mark. One tap, matching the one tap that made it (ADR 0202 D3).
    let onDelete: (Snag) -> Void

    var body: some View {
        CollapsiblePanel(title: "Snags",
                         summary: snags.isEmpty ? "None"
                            : "\(snags.count) snag\(snags.count == 1 ? "" : "s")",
                         expanded: $expanded) {
            if snags.isEmpty {
                EmptyPanelMessage(
                    systemImage: "waveform.path.ecg",
                    title: "No snags yet",
                    message: "Use the Snag button while a loop is running to mark a spot as you play past it.")
            } else {
                VStack(spacing: 8) {
                    ForEach(snags) { snag in
                        SnagRow(snag: snag,
                                loopName: snag.loopUID.flatMap { loopNames[$0] },
                                line: lines[snag.uid],
                                onSeek: { onSeek(snag) },
                                onEdit: { onEdit(snag) },
                                onDelete: { onDelete(snag) })
                    }
                    // A hold can't be seen, so say it, until a line shows what one looks like.
                    if !snags.contains(where: { lines[$0.uid] != nil }) {
                        Text("Hold a snag to leave a line on it, for when you come back.")
                            .font(.futura(.footnote))
                            .foregroundStyle(PocketColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct SnagRow: View {
    let snag: Snag
    /// The loop this mark was made under, when it still exists.
    let loopName: String?
    /// What the player wrote on it (ADR 0238), when they have.
    let line: String?
    let onSeek: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // The part that takes the tap and the hold. A bare tap target rather than a Button, so the
            // two compose (the marker row's reason), and the ✕ sits outside it so a long press on the ✕
            // can't open the sheet.
            VStack(alignment: .leading, spacing: 2) {
                mark
                if let line {
                    // Under the time, not the glyph, so the words read as the mark's own.
                    Text(line)
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 25)
                        .padding(.bottom, 8)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onSeek)
            .onLongPressGesture(minimumDuration: 0.4) {
                haptic(.medium)     // confirm the hold landed before the sheet appears
                onEdit()
            }
            // Delete is its own target rather than the row's hold, because the hold everywhere else
            // in these panels opens a sheet — and a hold that silently deletes instead would be the
            // one destructive gesture in the app with no confirmation and no sheet.
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.futura(.caption, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove this snag")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Go to this spot")
        .accessibilityAction(named: "Go here", onSeek)
        // VoiceOver can't long-press, so the hold is an action too.
        .accessibilityAction(named: line == nil ? "Add a line" : "Edit line", onEdit)
        .accessibilityAction(named: "Remove", onDelete)
    }

    /// The time, the loop and the speed, on one line.
    private var mark: some View {
        HStack(spacing: 10) {
            // The transport's glyph at row scale, so the tick on the waveform, the button that made
            // it and the row that holds it are visibly one thing.
            SnagCatch()
                .stroke(PocketColor.oracle,
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: 15, height: 15)
            Text(timecode(snag.seconds))
                .font(.pocketMono(.subheadline))
                .foregroundStyle(PocketColor.textPrimary)
                .accessibilityIdentifier("snags.time")    // what a UI test holds (ADR 0238)
            // The loop it was made under (ADR 0203 D2). `2:08` on its own is anonymous, and the
            // name is what makes a row mean something — but it is a **caption, not a grouping**: the
            // rows stay in song order, so two marks a beat apart sit together even when they were
            // made under different loops, which is the whole signal a cluster carries.
            if let loopName {
                Text(loopName)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
            // The speed it was marked at, when it wasn't full tempo. A snag at 0.6× and a snag at
            // 1.0× are not the same admission (ADR 0200) — but "1.00×" on every row is noise. It
            // keeps its width against a long loop name, which truncates instead.
            if let speed = snag.speed, abs(speed - 1.0) > 0.001 {
                Text(String(format: "%.2f×", speed))
                    .font(.pocketMono(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .layoutPriority(1)
            }
        }
        // Matches the marker row: a thin row needs the 44pt floor to sit level with the taller loop rows
        // above it, and the ✕ beside it is 44pt. A line goes under it, so the row grows past the floor.
        .frame(minHeight: 44)
    }

    private var accessibilityLabel: String {
        let mark = loopName.map { "Snag at \(timecode(snag.seconds)), \($0)" } ?? "Snag at \(timecode(snag.seconds))"
        return line.map { "\(mark). \($0)" } ?? mark
    }
}

#Preview("Snags panel") {
    @Previewable @State var expanded = true
    ZStack {
        PocketColor.background.ignoresSafeArea()
        let riff = UUID()
        let first = Snag(seconds: 31, speed: 0.75, loopUID: riff)
        SnagsPanel(snags: [first,
                           Snag(seconds: 34.4, speed: 0.75, loopUID: riff),
                           Snag(seconds: 128.2, loopUID: UUID())],  // its loop is gone — no caption
                   loopNames: [riff: "Post Solo Riff"],
                   lines: [first.uid: "Lose the slide into the 9th every time"],
                   expanded: $expanded, onSeek: { _ in }, onDelete: { _ in })
            .padding()
    }
}
