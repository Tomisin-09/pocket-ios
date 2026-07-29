import SwiftUI

// The markers panel (brief §4.1 item 11) — same list grammar and the same multi-select
// mode as the loops panel (ADR 0125), with **delete as the only bulk action**: a marker is
// a label and a time, so there is nothing else to set across several of them at once.
// Split from `WaveformPanels.swift` to keep both files inside the 400-line budget.

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
    /// Multi-select (ADR 0125).
    var selection = PanelSelectionSeam()

    var body: some View {
        CollapsiblePanel(title: "Markers",
                         summary: markers.isEmpty ? "None"
                            : "\(markers.count) marker\(markers.count == 1 ? "" : "s")",
                         expanded: $expanded,
                         onBeginSelection: markers.isEmpty ? nil : selection.begin,
                         isSelecting: selection.isActive) {
            if markers.isEmpty {
                EmptyPanelMessage(
                    systemImage: "mappin",
                    title: "No markers yet",
                    message: "Use the Mark button to drop a marker at the playhead.")
            } else {
                VStack(spacing: 8) {
                    ForEach(markers) { marker in
                        MarkerRow(marker: marker,
                                  isSelecting: selection.isActive,
                                  isSelected: selection.selection.contains(marker.uid),
                                  onSeek: { onSeek(marker) },
                                  onToggleSelection: { selection.toggle(marker.uid) },
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
    let isSelecting: Bool
    let isSelected: Bool
    let onSeek: () -> Void
    let onToggleSelection: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        // Tap the row to seek-and-play; press and hold (with a haptic) to open the
        // edit sheet — rename and delete live there (ADR 0028 / 0037, mirroring the
        // loop row). No pencil, no swipe: the hold is the one way in. A bare tap
        // target rather than a Button so tap + long-press compose cleanly. Selecting
        // re-points both gestures at the selection (ADR 0125).
        HStack(spacing: 10) {
            // The pin dot grows into the selection circle while selecting — the loop rows'
            // grammar in the marker list's own colour.
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.futura(.title3))
                    .foregroundStyle(PocketColor.pin.opacity(isSelected ? 1 : 0.55))
            } else {
                Circle().fill(PocketColor.pin).frame(width: 8, height: 8)
            }
            Text(marker.label)
                .font(.futura(.subheadline))
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
        .onTapGesture(perform: isSelecting ? onToggleSelection : onSeek)
        .onLongPressGesture(minimumDuration: 0.4) {
            // The selection toggle brings its own lighter haptic (see `LoopRow`).
            if isSelecting {
                onToggleSelection()
            } else {
                haptic(.medium)     // confirm the hold landed before the sheet appears
                onEdit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(isSelecting
                            ? (isSelected ? "\(marker.label), selected" : marker.label)
                            : "Go to \(marker.label)")
        .accessibilityAddTraits(isSelecting && isSelected ? .isSelected : [])
        // VoiceOver can't long-press, so surface the same actions explicitly.
        .accessibilityActions {
            if !isSelecting {
                Button("Edit", action: onEdit)
                Button("Delete", action: onDelete)
            }
        }
    }
}
