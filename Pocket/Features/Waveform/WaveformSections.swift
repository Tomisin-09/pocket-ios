import SwiftUI

// The individual sections of the waveform practice screen, top → bottom
// (design brief §4.1). Split out of `WaveformPracticeView` to keep each file
// focused; shared chrome (`CollapsiblePanel`, `panelBackground`) lives alongside
// the screen.

// MARK: - Formatting helpers

/// `M:SS` monospace timecode (brief §3.2 — mono for all time values).
func timecode(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
}

func stars(_ filled: Int) -> String {
    String(repeating: "★", count: filled) + String(repeating: "☆", count: max(0, 5 - filled))
}

// MARK: - 1. Song strip

struct SongStrip: View {
    let song: Song
    /// Hold the title/artist block to open the song details sheet (workstream 5).
    /// Defaulted to a no-op for previews and standalone use.
    var onHoldTitle: () -> Void = {}

    var body: some View {
        // P1a: a tight two-line title/artist stack with the proficiency stars beside it on
        // the right (rather than stacked below), so the header stays two lines tall and the
        // waveform + loops move up. The song length used to sit on the right; it's dropped
        // (`song.duration` is still used for marker/minimap math, just not shown here).
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.futura(.headline))
                    .foregroundStyle(PocketColor.textPrimary)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            // Derived song mastery (ADR 0036) — shown only when the song has loops to
            // roll up. An unrated song simply omits it (no length fallback anymore).
            if let mastery = song.mastery {
                Text(stars(mastery))
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.mastery)
                    .padding(.trailing, 4)   // nudge off the screen edge
                    .accessibilityLabel("Mastery \(mastery) of 5")
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.4) {
            haptic(.medium)     // confirm the hold landed before the sheet appears
            onHoldTitle()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Hold to view song details")
        // VoiceOver can't long-press, so surface the same action explicitly.
        .accessibilityAction(named: "Song details", onHoldTitle)
    }
}

// Section 3 (speed / BPM bar) lives in `WaveformSpeedBar.swift`.

// MARK: - 4. Interaction hint line

/// The default content under the speed bar (replaced by the A/B strip while a span is
/// live, or the downbeat strip while placing the 1). Rather than a long, truncating hint
/// line, this is a compact **Loop controls** affordance that opens a small popover with
/// the full gesture cheatsheet — A/B is the one creation story now.
struct ModeDescriptionLine: View {
    /// Gridlines toggle (ADR 0051) — shown on the right only once a grid exists (tempo +
    /// the 1 set). `gridOn` is the per-song `showsGridlines`.
    var gridAvailable = false
    var gridOn = true
    var onToggleGrid: () -> Void = {}
    /// Tempo set but no **1** placed (`model.needsDownbeat`) — the grid can't exist yet, so the Grid
    /// toggle's slot offers the missing step instead of standing empty. Device feedback 2026-07-29:
    /// setting only a BPM looked like the grid was broken, because nothing said the phase was missing.
    var needsDownbeat = false
    var onSetDownbeat: () -> Void = {}
    /// Open the song player's settings — **held** on the *Loop controls* affordance (ADR 0163). The
    /// four settings it opens describe this screen, and two of them already have controls in this very
    /// row, so the row that explains the screen's gestures is also where you adjust the screen itself.
    var onOpenPlayerSettings: () -> Void = {}
    @State private var showingInfo = false
    /// What pinch-zoom anchors to (ADR 0098) — off (the default) holds the spot under your fingers,
    /// on re-centres the window on the playhead. The setting already existed in Settings; this is the
    /// same `UserDefaults` key surfaced where the gesture is, since it's a per-moment choice (are you
    /// inspecting a spot, or chasing a moving playhead?) rather than a set-once preference.
    @AppStorage(AppSettings.Key.zoomFollowsPlayhead)
    private var zoomFollowsPlayhead = AppSettings.zoomFollowsPlayheadDefault

    var body: some View {
        HStack {
            // Tap = the gesture cheatsheet; **hold = the player's settings** (ADR 0163). A bare shape
            // with two gestures rather than a `Button` with a long press added, because that pairing
            // fires both — here it would show the popover *behind* the sheet. `MetronomeControl`'s
            // idiom. Idle-only comes free: this whole line is replaced by the A/B strip while a span
            // is live and by the downbeat bar while placing the 1, so there is no mid-gesture state
            // to guard against.
            Label("Loop controls", systemImage: "info.circle")
                .font(.futura(.footnote, weight: .medium))
                .foregroundStyle(PocketColor.textSecondary)
                .contentShape(Rectangle())
                .onTapGesture { showingInfo = true }
                .onLongPressGesture(minimumDuration: 0.4) {
                    haptic(.medium)     // confirm the hold landed before the sheet appears
                    onOpenPlayerSettings()
                }
                .popover(isPresented: $showingInfo) {
                    LoopControlsInfo().presentationCompactAdaptation(.popover)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Loop controls")
                .accessibilityHint("How the gestures work. Hold for the song player's settings")
                // VoiceOver can't long-press, so surface the hold's action explicitly.
                .accessibilityAction(named: Text("Player settings"), onOpenPlayerSettings)
            Spacer()
            // **Both toggles are chips, in the speed bar's `active` green.** Follow needs the state
            // cue on its own merits — its effect only shows on the *next* pinch, so a tinted label
            // read as a dead button (v2 close-out N1). Grid doesn't; it's a chip because the two sit
            // side by side, and a toggle next to a toggle that look like different kinds of control
            // is its own kind of wrong. The hue follows `PresetPill` in the speed bar directly above,
            // which is this screen's existing selected-chip idiom.
            ToggleChip(isOn: zoomFollowsPlayhead, tint: PocketColor.active) {
                zoomFollowsPlayhead.toggle()
            } content: {
                Label("Follow", systemImage: "scope")
                    .font(.futura(.footnote, weight: .medium))
            }
            .accessibilityLabel(zoomFollowsPlayhead ? "Zoom follows the playhead"
                                                    : "Zoom stays where you pinch")
            .accessibilityHint("Changes what pinch-to-zoom anchors to")
            .padding(.trailing, gridAvailable || needsDownbeat ? 8 : 0)
            if gridAvailable {
                ToggleChip(isOn: gridOn, tint: PocketColor.active, action: onToggleGrid) {
                    Label("Grid", systemImage: "grid")
                        .font(.futura(.footnote, weight: .medium))
                }
                .accessibilityLabel(gridOn ? "Hide gridlines" : "Show gridlines")
                .transition(.opacity)
            } else if needsDownbeat {
                // The tempo is known but the phase isn't, so there's nothing to draw yet. Say so, and
                // make the fix one tap — placing the 1 is what turns the BPM into a grid (ADR 0022/0024).
                //
                // **Deliberately not a chip**, unlike the Grid it stands in for: it's an action, not a
                // state, and a capsule fill would claim a "this is on" that a one-shot prompt doesn't
                // have. It also has to pull the eye — burying it in an unselected chip's grey would
                // undo the whole reason it exists (device feedback 2026-07-29).
                Button(action: onSetDownbeat) {
                    Label("Set the 1", systemImage: "1.circle")
                        .font(.futura(.footnote, weight: .medium))
                        .foregroundStyle(PocketColor.active)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Set the 1")
                .accessibilityHint("The tempo is set — place the downbeat to get gridlines")
                .transition(.opacity)
            }
        }
    }
}

/// The gesture cheatsheet shown by the **Loop controls** popover (ADR 0041).
private struct LoopControlsInfo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Loop controls")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            row("Make a loop", "Tap Loop to set the start, play on, tap to set the end")
            row("…or draw it", "Hold and drag across the waveform")
            row("Fine-tune", "Drag the A / B handles to move the ends")
            row("Re-edit later", "Drag a saved loop's edge on the waveform")
            row("Move around", "Tap or drag to seek · pinch to zoom · skip with − / +")
            row("Change the skip", "Hold either skip button to pick 5s · 10s · 15s · 30s · 1 min")
            row("Set the tempo", "Hold the metronome to open tap-tempo or type a BPM")
            row("Carry the tempo", "Hold the BPM to take it to the metronome or a new exercise")
            row("Follow", "Off: zoom holds the spot under your fingers · On: it tracks the playhead")
        }
        .padding(16)
        .frame(maxWidth: 290)
    }

    private func row(_ key: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(key).font(.futura(.footnote, weight: .semibold)).foregroundStyle(PocketColor.active)
            Text(detail).font(.futura(.caption)).foregroundStyle(PocketColor.textSecondary)
                // A popover sizes itself to its content's ideal width and will otherwise truncate a
                // detail longer than the 290-pt cap to one line (which is what the Follow row did on
                // device). `fixedSize` vertically lets any row wrap instead.
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 6. Time ruler

struct TimeRuler: View {
    /// The visible window in seconds — the whole song, or the zoomed slice when
    /// pinch-zoomed, so the axis labels match what's on screen.
    let start: TimeInterval
    let end: TimeInterval
    private let ticks = 5

    var body: some View {
        HStack {
            ForEach(0...ticks, id: \.self) { tick in
                Text(timecode(start + (end - start) * Double(tick) / Double(ticks)))
                    .font(.pocketMono(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
                if tick < ticks { Spacer() }
            }
        }
    }
}

// Section 8 (transport bar) lives in `WaveformTransportBar.swift`.
