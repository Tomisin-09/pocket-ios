import SwiftUI

// The two collapsible list panels at the bottom of the practice screen
// (brief §4.1 items 10–11): saved loops and markers, with their empty states.

// MARK: - 10. Loops panel

struct LoopsPanel: View {
    let loops: [Loop]
    @Binding var expanded: Bool
    let activeLoopID: UUID?
    let isPlaying: Bool
    /// Tap the row — activate (and play / toggle) this loop.
    let onActivate: (Loop) -> Void
    /// Swipe-Edit or hold the row — open the edit sheet (ADR 0028). Replaces the pencil.
    let onEdit: (Loop) -> Void
    /// Swipe-Delete — remove the loop without opening the sheet first.
    let onDelete: (Loop) -> Void
    /// The journal control — open this loop's practice journal (ADR 0038).
    let onJournal: (Loop) -> Void
    /// The "A" control — open this loop's automator (speed ramp) sheet.
    let onAutomator: (Loop) -> Void

    var body: some View {
        CollapsiblePanel(title: "Loops",
                         summary: loops.isEmpty ? "None"
                            : "\(loops.count) loop\(loops.count == 1 ? "" : "s")",
                         expanded: $expanded) {
            if loops.isEmpty {
                EmptyPanelMessage(
                    systemImage: "repeat",
                    title: "No loops yet",
                    message: "Tap Loop to set the start, play on, tap again to set the end "
                        + "— it loops that section. Save it to keep, or hold-drag the waveform.")
            } else {
                VStack(spacing: 8) {
                    ForEach(loops) { loop in
                        LoopRow(loop: loop,
                                isActive: loop.uid == activeLoopID,
                                isPlaying: isPlaying,
                                onActivate: { onActivate(loop) },
                                onJournal: { onJournal(loop) },
                                onAutomator: { onAutomator(loop) },
                                onEdit: { onEdit(loop) },
                                onDelete: { onDelete(loop) })
                    }
                }
            }
        }
    }
}

private struct LoopRow: View {
    let loop: Loop
    let isActive: Bool
    let isPlaying: Bool
    let onActivate: () -> Void
    let onJournal: () -> Void
    let onAutomator: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Tap the play area to activate (and play / toggle) the loop; press and
            // hold it (with a haptic) to open the edit sheet — rename, range, delete
            // all live there now (ADR 0028). No pencil, no swipe: the hold is the one
            // way in, which keeps the row's gestures clear of the scroll view. It's a
            // bare tap target rather than a Button so tap + long-press compose cleanly.
            HStack(spacing: 10) {
                // Active accent (green) down the leading edge.
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isActive ? PocketColor.active : Color.clear)
                    .frame(width: 3, height: 38)
                Image(systemName: isActive && isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isActive ? PocketColor.active : PocketColor.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(loop.name)
                        .font(.subheadline)
                        .foregroundStyle(PocketColor.textPrimary)
                        .lineLimit(1)
                    // Speed/repeats live in the automator (ADR 0013); the range plus the
                    // practice state (mastery + command tempo) make the row glanceable —
                    // each shown only when set, so an untouched loop reads as just a range
                    // and never a fake rating (ADR 0039).
                    LoopRowProgress(loop: loop)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onActivate)
            .onLongPressGesture(minimumDuration: 0.4) {
                haptic(.medium)     // confirm the hold landed before the sheet appears
                onEdit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(isActive && isPlaying ? "Pause \(loop.name)" : "Play \(loop.name)")
            // VoiceOver can't long-press, so surface the same actions explicitly.
            .accessibilityActions {
                Button("Edit", action: onEdit)
                Button("Journal", action: onJournal)
                Button("Delete", action: onDelete)
            }

            JournalButton(action: onJournal)
                .accessibilityLabel(loop.journal.isEmpty
                                    ? "Open journal for \(loop.name)"
                                    : "Journal for \(loop.name), \(loop.journal.count) "
                                        + "entr\(loop.journal.count == 1 ? "y" : "ies")")
            AutomatorButton(isOn: loop.automatorEnabled, action: onAutomator)
                .accessibilityLabel(loop.automatorEnabled
                                    ? "Automator on for \(loop.name)" : "Set up automator for \(loop.name)")
        }
    }
}

/// The loop row's second line (ADR 0039): the time range, plus mastery dots and a command-
/// tempo badge **only when those are set**. Absence is the unrated signal — an untouched loop
/// shows just its range, so nothing fake renders. Command tempo is the headline achievement,
/// so it reads as a small pill badge.
private struct LoopRowProgress: View {
    let loop: Loop

    var body: some View {
        HStack(spacing: 6) {
            Text("\(timecode(loop.startSeconds))–\(timecode(loop.endSeconds))")
                .font(.pocketMono(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
                .lineLimit(1)
            if loop.mastery != nil || loop.commandTempo != nil {
                Text("·").foregroundStyle(PocketColor.textSecondary)
                if let mastery = loop.mastery {
                    MasteryDots(filled: mastery)
                }
                if let percent = LoopProgressFormat.percent(loop.commandTempo) {
                    Text("\(percent)%")
                        .font(.pocketMono(.caption2).weight(.semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                        .lineLimit(1)
                        .fixedSize()   // keep the badge on one line; the range truncates first
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                        .accessibilityLabel("Command tempo \(percent) percent")
                }
            }
        }
    }
}

/// The journal control on a loop row, left of the "A" (ADR 0038) — a book glyph that
/// opens the loop's practice journal. It has **no on/off state**: unlike the automator
/// (which is genuinely armed or not), the journal is just a door, so it always reads
/// the same neutral way. Same 44pt target / compact badge as the automator button so
/// the two read as a pair.
private struct JournalButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "book.closed")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PocketColor.textSecondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(0.06)))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The "A" speed-ramp control on a loop row — tinted green when the loop's automator is
/// armed. A 44pt touch target around a compact badge.
private struct AutomatorButton: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("A")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isOn ? PocketColor.active : PocketColor.textSecondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(isOn ? PocketColor.active.opacity(0.18) : Color.white.opacity(0.06)))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 11. Markers panel

struct MarkersPanel: View {
    let markers: [Marker]
    @Binding var expanded: Bool
    /// Tap the row — seek the playhead to the marker (and play from there).
    let onSeek: (Marker) -> Void
    /// Hold the row — open the edit sheet (rename / delete). Mirrors the loop row;
    /// no pencil (ADR 0028 / 0037).
    let onEdit: (Marker) -> Void
    /// Delete the marker — surfaced for VoiceOver, which can't long-press.
    let onDelete: (Marker) -> Void

    var body: some View {
        CollapsiblePanel(title: "Markers",
                         summary: markers.isEmpty ? "None"
                            : "\(markers.count) marker\(markers.count == 1 ? "" : "s")",
                         expanded: $expanded) {
            if markers.isEmpty {
                EmptyPanelMessage(
                    systemImage: "mappin",
                    title: "No markers yet",
                    message: "Use the Mark button to drop a marker at the playhead.")
            } else {
                VStack(spacing: 8) {
                    ForEach(markers) { marker in
                        MarkerRow(marker: marker,
                                  onSeek: { onSeek(marker) },
                                  onEdit: { onEdit(marker) },
                                  onDelete: { onDelete(marker) })
                    }
                }
            }
        }
    }
}

private struct MarkerRow: View {
    let marker: Marker
    let onSeek: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        // Tap the row to seek-and-play; press and hold (with a haptic) to open the
        // edit sheet — rename and delete live there (ADR 0028 / 0037, mirroring the
        // loop row). No pencil, no swipe: the hold is the one way in. A bare tap
        // target rather than a Button so tap + long-press compose cleanly.
        HStack(spacing: 10) {
            Circle().fill(PocketColor.pin).frame(width: 8, height: 8)
            Text(marker.label)
                .font(.subheadline)
                .foregroundStyle(PocketColor.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(timecode(marker.seconds))
                .font(.pocketMono(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
        }
        // A marker row carries little content (a dot + label), so without a minimum
        // height it reads as cramped next to the taller loop rows. Pin it to the 44pt
        // touch-target height; the frame sits inside `contentShape` so the whole row
        // stays tappable / holdable.
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSeek)
        .onLongPressGesture(minimumDuration: 0.4) {
            haptic(.medium)     // confirm the hold landed before the sheet appears
            onEdit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Go to \(marker.label)")
        // VoiceOver can't long-press, so surface the same actions explicitly.
        .accessibilityActions {
            Button("Edit", action: onEdit)
            Button("Delete", action: onDelete)
        }
    }
}
