import SwiftUI

// The loops panel at the bottom of the practice screen (brief §4.1 item 10), with its
// empty state and its multi-select mode (ADR 0125). The markers panel — same grammar,
// fewer bulk actions — lives in `WaveformPanels+Markers.swift`.

/// The multi-select seam a reference panel needs (ADR 0125): the state to render plus the
/// intents to raise, bundled so each panel doesn't grow half a dozen more parameters. The
/// closures default to no-ops so previews and any non-selecting host can ignore it
/// entirely — the same "closures in the environment, not the object" discipline the row
/// actions modifier uses, kept explicit here because there are only two call sites.
struct PanelSelectionSeam {
    var selection = PanelSelection()
    var begin: () -> Void = {}
    var toggle: (UUID) -> Void = { _ in }
    var toggleAll: () -> Void = {}
    var end: () -> Void = {}
    var delete: () -> Void = {}

    var isActive: Bool { selection.isActive }
}

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
    /// The fine-adjust control — lift this loop into the A/B span for a direct range edit
    /// on the waveform (ADR 0067). Replaces the old journal book, which moved into the loop
    /// edit sheet; the journal is authored from Practice (ADR 0058).
    let onAdjustRange: (Loop) -> Void
    /// The "A" control — open this loop's automator (speed ramp) sheet.
    let onAutomator: (Loop) -> Void
    /// Multi-select (ADR 0125).
    var selection = PanelSelectionSeam()
    /// Bulk star. `favoriteAdds` drives the glyph so the control shows what it will *do*:
    /// a hollow star adds, a filled one takes the star back off an all-favourited selection.
    var favoriteAdds = true
    var onBulkFavorite: () -> Void = {}
    /// The chevron's old slot: bulk practice categories (type · focus · tags).
    var onBulkCategories: () -> Void = {}
    /// Landscape drawer (ADR 0042): tighten each row (no range, closer icons).
    var compact: Bool = false

    var body: some View {
        CollapsiblePanel(title: "Loops",
                         summary: loops.isEmpty ? "None"
                            : "\(loops.count) loop\(loops.count == 1 ? "" : "s")",
                         expanded: $expanded,
                         onBeginSelection: loops.isEmpty ? nil : selection.begin,
                         isSelecting: selection.isActive) {
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
                                color: LoopColor.color(for: loop, among: loops),
                                isActive: loop.uid == activeLoopID,
                                isPlaying: isPlaying,
                                isSelecting: selection.isActive,
                                isSelected: selection.selection.contains(loop.uid),
                                onActivate: { onActivate(loop) },
                                onToggleSelection: { selection.toggle(loop.uid) },
                                onAdjustRange: { onAdjustRange(loop) },
                                onAutomator: { onAutomator(loop) },
                                onEdit: { onEdit(loop) },
                                onDelete: { onDelete(loop) },
                                compact: compact)
                    }
                }
            }
        } selectionHeader: {
            PanelSelectionHeader(
                title: PanelSelection.title(count: selection.selection.count,
                                            noun: "loop", plural: "loops"),
                allSelected: selection.selection.allSelected(of: loops.map(\.uid)),
                onToggleAll: selection.toggleAll,
                onDone: selection.end) {
                    let any = !selection.selection.isEmpty
                    PanelActionButton(systemImage: "trash", label: "Delete selected loops",
                                      isEnabled: any, tint: PocketColor.danger,
                                      action: selection.delete)
                    PanelActionButton(systemImage: favoriteAdds ? "star" : "star.slash",
                                      label: favoriteAdds ? "Favourite selected loops"
                                                          : "Remove selected loops from favourites",
                                      isEnabled: any, action: onBulkFavorite)
                    PanelActionButton(systemImage: "slider.horizontal.3",
                                      label: "Edit practice categories for the selected loops",
                                      isEnabled: any, action: onBulkCategories)
                }
        }
    }
}

private struct LoopRow: View {
    let loop: Loop
    /// The loop's identity colour (ADR 0023) — now carried by the row itself, so a song's
    /// loops read as the same set of hues in the list as on the waveform and minimap.
    let color: Color
    let isActive: Bool
    let isPlaying: Bool
    let isSelecting: Bool
    let isSelected: Bool
    let onActivate: () -> Void
    let onToggleSelection: () -> Void
    let onAdjustRange: () -> Void
    let onAutomator: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    /// Landscape drawer: drops the row's time range and tightens the adjust/automator
    /// pair so the panel fits a narrower drawer with room to spare (ADR 0042).
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            // Tap the play area to activate (and play / toggle) the loop; press and
            // hold it (with a haptic) to open the edit sheet — rename, range, delete
            // all live there now (ADR 0028). No pencil, no swipe: the hold is the one
            // way in, which keeps the row's gestures clear of the scroll view. It's a
            // bare tap target rather than a Button so tap + long-press compose cleanly.
            // While selecting, both gestures are re-pointed at the selection (ADR 0125).
            HStack(spacing: 10) {
                // Active accent (green) down the leading edge. It stays green now that the
                // glyph carries the identity colour: two coloured elements and nothing would
                // be left saying *which loop is playing*.
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isActive ? PocketColor.active : Color.clear)
                    .frame(width: 3, height: 38)
                glyph
                VStack(alignment: .leading, spacing: 2) {
                    Text(loop.name)
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textPrimary)
                        .lineLimit(1)
                    // Speed/repeats live in the automator (ADR 0013); the range plus the
                    // practice state (mastery + command tempo) make the row glanceable —
                    // each shown only when set, so an untouched loop reads as just a range
                    // and never a fake rating (ADR 0039).
                    LoopRowProgress(loop: loop, compact: compact)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: isSelecting ? onToggleSelection : onActivate)
            .onLongPressGesture(minimumDuration: 0.4) {
                // While selecting, the toggle brings its own lighter haptic — a hold and a
                // tap must not feel like two different weights of the same action.
                if isSelecting {
                    onToggleSelection()
                } else {
                    haptic(.medium)     // confirm the hold landed before the sheet appears
                    onEdit()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(isSelecting && isSelected ? .isSelected : [])
            // VoiceOver can't long-press, so surface the same actions explicitly.
            .accessibilityActions {
                if !isSelecting {
                    Button("Edit", action: onEdit)
                    Button("Adjust range", action: onAdjustRange)
                    Button("Delete", action: onDelete)
                }
            }

            // Adjust + automator read as a pair; in the narrow landscape drawer they sit
            // closer together (their 44pt targets keep a usable gap) to reclaim width.
            // Both hide while selecting so a mis-tap can't open a sheet over the selection.
            if !isSelecting {
                HStack(spacing: compact ? -6 : 10) {
                    AdjustRangeButton(action: onAdjustRange)
                        .accessibilityLabel("Adjust range for \(loop.name)")
                    AutomatorButton(isOn: loop.automatorEnabled, action: onAutomator)
                        .accessibilityLabel(loop.automatorEnabled
                                            ? "Automator on for \(loop.name)" : "Set up automator for \(loop.name)")
                }
            }
        }
    }

    /// The row's leading glyph. Browsing, it's the transport control in the loop's identity
    /// colour — **muted unless this is the armed loop**, so hue reads as identity and
    /// saturation reads as state. Selecting, it becomes the selection circle in that same
    /// hue, filling when chosen (ADR 0125).
    private var glyph: some View {
        Image(systemName: glyphName)
            .font(.futura(.title2))
            .foregroundStyle(color.opacity(isSelecting ? (isSelected ? 1 : 0.55)
                                                       : (isActive ? 1 : 0.55)))
    }

    private var glyphName: String {
        if isSelecting { return isSelected ? "checkmark.circle.fill" : "circle" }
        return isActive && isPlaying ? "pause.circle.fill" : "play.circle.fill"
    }

    private var accessibilityLabel: String {
        if isSelecting { return isSelected ? "\(loop.name), selected" : loop.name }
        return isActive && isPlaying ? "Pause \(loop.name)" : "Play \(loop.name)"
    }
}

/// The loop row's second line (ADR 0039): the time range, plus mastery dots and a command-
/// tempo badge **only when those are set**. Absence is the unrated signal — an untouched loop
/// shows just its range, so nothing fake renders. Command tempo is the headline achievement,
/// so it reads as a small pill badge.
private struct LoopRowProgress: View {
    let loop: Loop
    /// Landscape drawer: drop the time range (it's on the waveform) to keep the narrow
    /// row uncluttered — just the mastery dots + command-tempo badge remain (ADR 0042).
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if !compact {
                Text("\(timecode(loop.startSeconds))–\(timecode(loop.endSeconds))")
                    .font(.pocketMono(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .lineLimit(1)
            }
            if loop.mastery != nil || loop.commandTempo != nil {
                if !compact { Text("·").foregroundStyle(PocketColor.textSecondary) }
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
                        .background(Capsule().fill(PocketColor.surfaceStandard))
                        .accessibilityLabel("Command tempo \(percent) percent")
                }
            }
        }
    }
}

/// The fine-adjust control on a loop row, left of the "A" (ADR 0067) — lifts the loop into
/// the A/B span so its bounds can be dragged on the waveform, the same handle mechanics as
/// the edit sheet's "Adjust range." It has **no on/off state** (unlike the automator, which is
/// genuinely armed): it's just a door, so it always reads the same neutral way. Same 44pt
/// target / compact badge as the automator button so the two read as a pair.
private struct AdjustRangeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "slider.horizontal.below.rectangle")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(PocketColor.surfaceStandard))
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
                .font(.futura(.subheadline, weight: .bold))
                .foregroundStyle(isOn ? PocketColor.active : PocketColor.textSecondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(isOn ? PocketColor.active.opacity(0.18) : PocketColor.surfaceStandard))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
