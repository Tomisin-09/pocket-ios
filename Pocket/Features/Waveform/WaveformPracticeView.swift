import SwiftUI

/// The core practice screen (design brief §4.1). Iteration 1 is the **static
/// layout skeleton in its default (paused) state**: the vertical rhythm,
/// hierarchy and token usage for every section, driven by mock data. Gestures,
/// the audio engine, the asymmetric speed scale, the loop-creation sheet and the
/// non-default states (loading/empty/error/playing) are later single-axis
/// iterations.
///
/// Everything references `PocketColor` / `Font.pocketMono` — no raw hex, no
/// hard-coded point sizes where a text style fits. The individual sections live
/// in `WaveformSections.swift`.
struct WaveformPracticeView: View {

    /// Transport interaction modes — pills in the transport bar (brief §4.1).
    enum InteractionMode: String, CaseIterable, Identifiable {
        case scroll = "Scroll"
        case tap = "Tap"
        case fine = "Fine"
        var id: String { rawValue }

        /// One-line description shown under the speed bar.
        var blurb: String {
            switch self {
            case .scroll: "Tap to set the playhead · hold to drop a marker"
            case .tap: "Tap to set loop start, tap again to close the loop"
            case .fine: "Drag the blue handles to fine-tune the loop bounds"
            }
        }
    }

    private let song = WaveformMock.song

    // UI state (visual only in this iteration — no engine wired yet).
    @State private var speed: Double = 1.0
    @State private var mode: InteractionMode = .scroll
    @State private var songInfoExpanded = false   // demoted to the scroll area
    @State private var loopsExpanded = true
    @State private var markersExpanded = false
    @State private var isPlaying = false
    @State private var repeatOn = true

    // Loops/markers are mutable so they can be activated, renamed and deleted.
    @State private var loops = WaveformMock.song.loops
    @State private var markers = WaveformMock.song.markers
    @State private var activeLoopID: WaveformMock.Loop.ID? = WaveformMock.song.loops.first?.id
    @State private var editingLoop: WaveformMock.Loop?
    @State private var editingMarker: WaveformMock.Marker?
    /// The loop being captured (drives the inline creation panel).
    @State private var draftLoop: WaveformMock.Loop?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Read-only BPM display: round(songBPM × speed) — brief §4.1 speed bar.
    private var displayedBPM: Int { Int((Double(song.bpm) * speed).rounded()) }

    /// The loop currently loaded into the transport/waveform, if any.
    private var activeLoop: WaveformMock.Loop? { loops.first { $0.id == activeLoopID } }

    var body: some View {
        ZStack {
            PocketColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Fixed practice surface — the controls you touch constantly,
                // pinned so they never scroll away (brief items 1, 3–8).
                VStack(spacing: 16) {
                    SongStrip(song: song)                                    // 1
                    SpeedBar(speed: $speed, displayedBPM: displayedBPM)      // 3
                    ModeDescriptionLine(mode: mode)                          // 4
                    WaveformView(amplitudes: song.amplitudes,                // 5
                                 playheadFraction: song.playheadFraction,
                                 loop: activeLoop)
                    TimeRuler(duration: song.duration)                      // 6
                    Minimap(song: song, activeLoop: activeLoop, markers: markers) // 7
                    TransportBar(isPlaying: $isPlaying,                      // 8
                                 repeatOn: $repeatOn,
                                 mode: $mode,
                                 currentTime: song.playheadSeconds,
                                 loop: activeLoop,
                                 onCapture: capture)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)

                // 9. Loop creation sheet — slides in below the transport while a
                //    loop is being captured, so it can be named on capture.
                if let draft = draftLoop {
                    LoopCreationPanel(
                        range: "\(timecode(draft.startSeconds))–\(timecode(draft.endSeconds))",
                        onSave: saveCapturedLoop,
                        onDiscard: dismissDraft)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(reduceMotion
                                    ? .opacity
                                    : .move(edge: .bottom).combined(with: .opacity))
                }

                // Hairline boundary between the fixed surface and the scroll area.
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                // Scrollable reference — loops, markers, then song info (demoted
                // to the bottom, collapsed by default). Item 9 (the loop-creation
                // sheet) appears only while a loop is being captured.
                ScrollView {
                    VStack(spacing: 16) {
                        LoopsPanel(loops: loops, expanded: $loopsExpanded,       // 10
                                   activeLoopID: activeLoopID, isPlaying: isPlaying,
                                   onActivate: activate, onEdit: { editingLoop = $0 })
                        MarkersPanel(markers: markers, expanded: $markersExpanded, // 11
                                     onEdit: { editingMarker = $0 })
                        SongInfoPanel(song: song, expanded: $songInfoExpanded)   // 2
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $editingLoop) { loop in
            LoopEditSheet(loop: loop, onSave: updateLoop, onDelete: { deleteLoop(loop) })
        }
        .sheet(item: $editingMarker) { marker in
            MarkerEditSheet(marker: marker, onSave: updateMarker, onDelete: { deleteMarker(marker) })
        }
    }

    // MARK: Loop/marker actions

    /// Capture a draft loop around the playhead and open the creation panel.
    private func capture() {
        guard draftLoop == nil else { return }
        let start = min(song.playheadFraction, 0.85)
        let end = min(start + 0.12, 0.98)
        let draft = WaveformMock.Loop(name: "", start: start, end: end,
                                      speed: speed, repeats: 4, duration: song.duration)
        withAnimation(.easeOut(duration: 0.28)) { draftLoop = draft }
    }

    /// Save the captured loop with its name (empty → fall back to the range).
    private func saveCapturedLoop(_ name: String) {
        guard var draft = draftLoop else { return }
        let range = "\(timecode(draft.startSeconds))–\(timecode(draft.endSeconds))"
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        draft.name = trimmed.isEmpty ? range : trimmed
        loops.append(draft)
        activeLoopID = draft.id
        withAnimation(.easeOut(duration: 0.28)) { draftLoop = nil }
    }

    private func dismissDraft() {
        withAnimation(.easeOut(duration: 0.2)) { draftLoop = nil }
    }

    /// Tapping a loop's play button: activate it, or toggle play if already active.
    private func activate(_ loop: WaveformMock.Loop) {
        if activeLoopID == loop.id {
            isPlaying.toggle()
        } else {
            activeLoopID = loop.id
            isPlaying = true
        }
    }

    private func updateLoop(_ loop: WaveformMock.Loop) {
        guard let index = loops.firstIndex(where: { $0.id == loop.id }) else { return }
        loops[index] = loop
    }

    private func deleteLoop(_ loop: WaveformMock.Loop) {
        loops.removeAll { $0.id == loop.id }
        if activeLoopID == loop.id { activeLoopID = loops.first?.id }
    }

    private func updateMarker(_ marker: WaveformMock.Marker) {
        guard let index = markers.firstIndex(where: { $0.id == marker.id }) else { return }
        markers[index] = marker
    }

    private func deleteMarker(_ marker: WaveformMock.Marker) {
        markers.removeAll { $0.id == marker.id }
    }
}

// MARK: - Shared chrome

/// Collapsible panel: chevron + a summary line when collapsed, so the user is
/// never left wondering what's hidden (brief §3.4).
struct CollapsiblePanel<Content: View>: View {
    let title: String
    let summary: String
    @Binding var expanded: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                    Spacer()
                    if !expanded {
                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(PocketColor.textSecondary)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded { content }
        }
        .padding(14)
        .background(panelBackground)
    }
}

/// Standard panel surface — a hair lighter than the near-black background.
var panelBackground: some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color.white.opacity(0.04))
}

// MARK: - Formatting helpers

/// `M:SS` monospace timecode (brief §3.2 — mono for all time values).
func timecode(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
}

func stars(_ filled: Int) -> String {
    String(repeating: "★", count: filled) + String(repeating: "☆", count: max(0, 5 - filled))
}

#Preview {
    WaveformPracticeView()
}
