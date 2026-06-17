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
    /// Trailing pencil — open the edit sheet.
    let onEdit: (Loop) -> Void
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
                    message: "Use the Loop button to punch a section as it plays, "
                        + "or Fine to drag the bounds.")
            } else {
                VStack(spacing: 8) {
                    ForEach(loops) { loop in
                        LoopRow(loop: loop,
                                isActive: loop.uid == activeLoopID,
                                isPlaying: isPlaying,
                                onActivate: { onActivate(loop) },
                                onAutomator: { onAutomator(loop) },
                                onEdit: { onEdit(loop) })
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
    let onAutomator: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Tap the row to activate (and play / toggle) the loop.
            Button(action: onActivate) {
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
                        // Speed/repeats moved into the automator (ADR 0013) — the row
                        // shows just the range now; the "A" control holds the ramp.
                        Text("\(timecode(loop.startSeconds))–\(timecode(loop.endSeconds))")
                            .font(.pocketMono(.footnote))
                            .foregroundStyle(PocketColor.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isActive && isPlaying ? "Pause \(loop.name)" : "Play \(loop.name)")

            AutomatorButton(isOn: loop.automatorEnabled, action: onAutomator)
                .accessibilityLabel(loop.automatorEnabled
                                    ? "Automator on for \(loop.name)" : "Set up automator for \(loop.name)")

            EditPencil { onEdit() }
                .accessibilityLabel("Edit \(loop.name)")
        }
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

/// Shared trailing edit affordance for loop and marker rows.
private struct EditPencil: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "pencil")
                .font(.body)
                .foregroundStyle(PocketColor.textSecondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 11. Markers panel

struct MarkersPanel: View {
    let markers: [Marker]
    @Binding var expanded: Bool
    /// Tap the row — seek the playhead to the marker.
    let onSeek: (Marker) -> Void
    /// Trailing pencil — open the edit sheet (rename / delete).
    let onEdit: (Marker) -> Void

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
                        HStack(spacing: 10) {
                            // Tap the row to seek the playhead to the marker.
                            Button { onSeek(marker) } label: {
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
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Go to \(marker.label)")

                            EditPencil { onEdit(marker) }
                                .accessibilityLabel("Edit \(marker.label)")
                        }
                    }
                }
            }
        }
    }
}
