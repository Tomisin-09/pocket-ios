import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// The custom-drawn parts of the waveform practice screen (brief §4.1, items 5
// and 7). Kept separate from the declarative layout sections because this is
// imperative Canvas drawing — a different category of code.

// MARK: - 5. Waveform — SoundCloud-style mirrored bars + gesture engine

/// The detail waveform. Renders the mirrored bars, the active loop region, the
/// in-progress selection, and the playhead, and recognises two interaction modes
/// (brief §4.1 / ADR 0005):
///
/// - **Navigate** (default): tap → seek the playhead; drag → scrub; **hold-drag →
///   select a loop region** (ADR 0005 round 5); pinch → zoom.
/// - **Fine:** drag the two blue handles to set the loop bounds.
///
/// Marker drop and loop punch are also buttons on the transport action bar (they act
/// at the playhead); the hold-drag is the on-waveform path to define a loop *range*.
/// All gesture math (point → fraction, zoom
/// viewport, handle hit-testing) lives in the pure, unit-tested `WaveformGesture`;
/// the view emits *song fractions* (0…1) so the parent never deals in points.
/// Crisp deep-zoom (ADR 0020): a re-downsample of just the visible window plus the
/// song range `[start, end]` it covers. When the waveform has one, it's drawn instead
/// of stretching the stored whole-song envelope, so a deep zoom resolves real detail.
struct WaveformDetailBars: Equatable {
    let bars: [Double]
    let start: Double
    let end: Double
}

struct WaveformView: View {
    let amplitudes: [Double]
    /// The crisp windowed bars to draw, or `nil` to fall back to the stored whole-song
    /// envelope (`amplitudes`, covering `[0, 1]`).
    let detailBars: WaveformDetailBars?
    let playheadFraction: Double
    let loop: Loop?
    /// Every saved loop on the song — drawn as lane-stacked brackets along the
    /// bottom so the whole loop library reads against the timeline, not just the
    /// active one. Overlap is shown by lane (vertical position); colour stays
    /// reserved for state (the active loop's bracket is brighter). See ADR 0018.
    let loops: [Loop]
    /// Saved markers as song fractions (0…1) — drawn as pins dropping from the top.
    let markerFractions: [Double]
    /// The beat grid (ADR 0022): beats + bar-start downbeats as song fractions, drawn
    /// faintly behind the bars (downbeats brighter). Empty when the song has no tempo
    /// or no downbeat anchor, so the whole grid simply doesn't render. Defaulted so
    /// the many component previews/call sites that don't care opt out for free.
    var beats: [BeatGrid.Beat] = []
    let mode: WaveformPracticeView.InteractionMode
    /// Loop punch in progress: the start of the loop being captured. The region from
    /// here to the live playhead fills green as playback previews it.
    let formingStart: Double?
    /// Fine mode: the selection being dragged by the two blue handles.
    let fineSelection: (start: Double, end: Double)?
    /// A punched loop awaiting confirm — a static green highlight so it stays visible
    /// while the edit toolbar is up.
    let tapSelection: (start: Double, end: Double)?
    /// Live playhead time, shown in a bubble pinned to the playhead.
    let playheadLabel: String

    let onSeek: (Double) -> Void
    let onScrub: (Double) -> Void
    let onMoveHandle: (WaveformGesture.Handle, Double) -> Void
    /// Fine mode: the drag finished — commit the live audio preview to the new bounds.
    let onMoveHandleEnded: () -> Void
    /// Long-press-drag select (navigate mode): a hold fired — begin a selection at
    /// this fraction. The drag then extends it (`onSelectChanged`).
    let onSelectBegan: (Double) -> Void
    /// The hold-drag moved — grow the live selection to this fraction.
    let onSelectChanged: (Double) -> Void
    /// The hold-drag released — commit the selection into a confirmable draft.
    let onSelectEnded: () -> Void
    /// A pinch (or other interruption) took over mid-hold-drag — abort the selection.
    let onSelectCancelled: () -> Void
    /// Pinch-to-zoom: the visible window of the song (song fractions). Both the
    /// rendering and the touch→song-fraction mapping go through it.
    let viewport: (start: Double, end: Double)
    /// Pinch magnification → set the new zoom span (visible fraction of the song).
    let onSetZoomSpan: (Double) -> Void

    // Gesture bookkeeping. Not `private` — the gesture recogniser lives in a
    // `WaveformView` extension in `WaveformCanvasGestures.swift`, so it reads this
    // state across files within the module.
    @State var dragStartX: CGFloat?
    @State var didScrub = false                     // moved enough to be a scrub (not a tap)
    @State var grabbedHandle: WaveformGesture.Handle?  // Fine mode
    @State var pinchBaseSpan: Double?               // zoom span captured at pinch start
    @State var didPinch = false                     // a pinch happened — swallow the trailing tap/scrub
    // Long-press-drag select (navigate). A still hold arms a selection; the drag
    // then paints it instead of scrubbing (ADR 0005 round 5).
    @State var longPressTask: Task<Void, Never>?    // pending hold timer
    @State var isSelecting = false                  // armed — the drag is painting a loop
    @State var holdFraction: Double = 0             // where a firing hold anchors (tracks the still finger)

    let scrubThreshold: CGFloat = 6                 // px before a press counts as a scrub vs a tap
    let handleTolerance = 0.06                      // fraction either side of a handle that grabs it
    let longPressDuration: Duration = .milliseconds(350)  // still-hold before a drag becomes a selection

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    draw(in: context, size: size)
                }
                // Live time bubble, pinned above the playhead and clamped so it
                // never runs off either edge.
                TimeBubble(text: playheadLabel)
                    .position(x: bubbleX(width: geo.size.width), y: 12)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(width: geo.size.width))
            .simultaneousGesture(magnifyGesture)
        }
        .frame(height: 140)
        .accessibilityElement()
        .accessibilityLabel("Waveform")
        .accessibilityHint(mode.blurb)
    }

    // MARK: Drawing

    private func draw(in context: GraphicsContext, size: CGSize) {
        // Crisp windowed bars when available, else the stretched whole-song envelope
        // (ADR 0020). The set carries the song range its bars describe.
        let barSet = detailBars ?? WaveformDetailBars(bars: amplitudes, start: 0, end: 1)
        guard !barSet.bars.isEmpty else { return }
        let midY = size.height / 2
        // Song fraction → on-screen x (through the zoom viewport).
        func atX(_ songFraction: Double) -> CGFloat { CGFloat(screenX(songFraction)) * size.width }
        let playheadX = atX(playheadFraction)

        // Beat grid behind everything (ADR 0022) — faint structure the bars, regions,
        // and annotations all sit on top of.
        drawBeatGrid(in: context, size: size, atX: atX)

        // Active loop region (amber while paused — green is reserved for playing).
        if let loop {
            let startX = atX(loop.start)
            let rect = CGRect(x: startX, y: 0, width: atX(loop.end) - startX, height: size.height)
            context.fill(Path(rect), with: .color(PocketColor.marker.opacity(0.14)))
        }

        // Forming loop (Tap mode) — fills green from the start to the playhead as
        // playback previews the section being captured.
        if let formingStart {
            let lowerX = atX(min(formingStart, playheadFraction))
            let upperX = atX(max(formingStart, playheadFraction))
            context.fill(Path(CGRect(x: lowerX, y: 0, width: upperX - lowerX, height: size.height)),
                         with: .color(PocketColor.active.opacity(0.22)))
        }

        // Captured Tap loop awaiting confirm — static green highlight.
        if let tapSelection {
            let startX = atX(tapSelection.start)
            context.fill(Path(CGRect(x: startX, y: 0, width: atX(tapSelection.end) - startX, height: size.height)),
                         with: .color(PocketColor.active.opacity(0.22)))
        }

        // Fine selection (blue region + two draggable handles).
        if let fineSelection {
            let startX = atX(fineSelection.start)
            let endX = atX(fineSelection.end)
            let rect = CGRect(x: startX, y: 0, width: endX - startX, height: size.height)
            context.fill(Path(rect), with: .color(PocketColor.fine.opacity(0.18)))
            for handleX in [startX, endX] {
                let bar = CGRect(x: handleX - 1.5, y: 0, width: 3, height: size.height)
                context.fill(Path(bar), with: .color(PocketColor.fine))
                let knob = CGRect(x: handleX - 5, y: midY - 9, width: 10, height: 18)
                context.fill(Path(roundedRect: knob, cornerRadius: 3), with: .color(PocketColor.fine))
            }
        }

        drawBars(in: context, size: size, barSet: barSet, playheadX: playheadX)

        // Saved-loop brackets (bottom, lane-stacked) and marker pins (top). Drawn
        // over the bars so the whole loop/marker library reads against the timeline.
        drawLoopBrackets(in: context, size: size, atX: atX)
        drawMarkerPins(in: context, size: size, atX: atX)

        // Playhead.
        var line = Path()
        line.move(to: CGPoint(x: playheadX, y: 0))
        line.addLine(to: CGPoint(x: playheadX, y: size.height))
        context.stroke(line, with: .color(PocketColor.textPrimary.opacity(0.8)), lineWidth: 1.5)
    }

    /// Mirrored bars for the visible slice of the song. `barSet` either covers the
    /// whole song (`[0, 1]`, stretched through the viewport) or just the zoomed window
    /// (crisp re-downsample, ADR 0020); each bar is placed at its centre within the
    /// range it covers, then mapped through the viewport.
    private func drawBars(in context: GraphicsContext, size: CGSize,
                          barSet: WaveformDetailBars, playheadX: CGFloat) {
        let count = barSet.bars.count
        guard count > 0 else { return }
        let midY = size.height / 2
        let span = max(0.0001, viewport.end - viewport.start)
        // On-screen distance between bars: each covers (covered span)/count of the
        // song, and the viewport's span maps to the full width.
        let pitch = size.width * CGFloat(barSet.end - barSet.start) / (CGFloat(count) * CGFloat(span))
        let barWidth = max(1, pitch - 1)   // 1px inter-bar spacing
        for (index, amp) in barSet.bars.enumerated() {
            let songFraction = WaveformGesture.barCentreFraction(
                index: index, count: count, coveredStart: barSet.start, coveredEnd: barSet.end)
            let barX = CGFloat(screenX(songFraction)) * size.width
            guard barX > -barWidth, barX < size.width else { continue }   // off-screen
            let color = barX <= playheadX ? PocketColor.waveformBarPlayed : PocketColor.waveformBar
            let topHeight = CGFloat(amp) * midY
            context.fill(Path(CGRect(x: barX, y: midY - topHeight, width: barWidth, height: topHeight)),
                         with: .color(color))
            // Reflection at ~60% — brief §4.1.
            context.fill(Path(CGRect(x: barX, y: midY, width: barWidth, height: topHeight * 0.6)),
                         with: .color(color.opacity(0.6)))
        }
    }

    // Bracket layout (overlay, ADR 0018): brackets live in the dead space below
    // the reflected bars, stacked upward from the bottom. Capped at `maxLanes` so
    // deep nesting can't march up into the bars — anything deeper clamps into the
    // last lane.
    private static let maxLanes = 3
    private static let laneHeight: CGFloat = 7
    private static let bracketPadding: CGFloat = 3
    // Feet are taller on the active loop so it reads as the foreground even where a
    // parked bracket shares its lane height (visual-polish pass, ADR 0018 follow-up).
    private static let bracketFootActive: CGFloat = 6
    private static let bracketFootSaved: CGFloat = 4

    /// All saved loops as lane-stacked brackets along the bottom. Overlap is shown
    /// by lane; colour is reserved for state — the active loop's bracket is full
    /// amber, the rest are dimmed. The active loop is drawn last so it stays on top.
    ///
    /// Polish pass (ADR 0018 follow-up): rounded caps soften the corners, the active
    /// loop is heavier (2.5 pt, full opacity, taller feet) against dimmer parked
    /// brackets (1.5 pt, 0.4 opacity), and a near-background halo lifts every bracket
    /// off the bar reflections so a parked loop stays legible over a loud transient.
    private func drawLoopBrackets(in context: GraphicsContext, size: CGSize,
                                  atX: (Double) -> CGFloat) {
        guard !loops.isEmpty else { return }
        let packing = LoopLanes.pack(loops.map {
            LoopLanes.Interval(id: $0.uid, start: $0.start, end: $0.end)
        })

        func bracket(_ loop: Loop, isActive: Bool) {
            let startX = atX(loop.start)
            let endX = atX(loop.end)
            guard endX > 0, startX < size.width else { return }       // off-screen
            let lane = min(packing.lane(for: loop.uid), Self.maxLanes - 1)
            let baseY = size.height - Self.bracketPadding - CGFloat(lane) * Self.laneHeight
            let foot = isActive ? Self.bracketFootActive : Self.bracketFootSaved

            var path = Path()
            path.move(to: CGPoint(x: max(0, startX), y: baseY))
            path.addLine(to: CGPoint(x: min(size.width, endX), y: baseY))
            // Feet point up at the *true* ends — only where the end is on-screen.
            if startX >= 0 {
                path.move(to: CGPoint(x: startX, y: baseY))
                path.addLine(to: CGPoint(x: startX, y: baseY - foot))
            }
            if endX <= size.width {
                path.move(to: CGPoint(x: endX, y: baseY))
                path.addLine(to: CGPoint(x: endX, y: baseY - foot))
            }
            let width: CGFloat = isActive ? 2.5 : 1.5
            // Contrast halo behind, then the amber bracket. Round caps on both.
            context.stroke(path, with: .color(PocketColor.background.opacity(0.55)),
                           style: StrokeStyle(lineWidth: width + 1.5, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(PocketColor.marker.opacity(isActive ? 1.0 : 0.4)),
                           style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }

        let activeUID = loop?.uid
        for loop in loops where loop.uid != activeUID { bracket(loop, isActive: false) }
        if let active = loop, loops.contains(where: { $0.uid == active.uid }) {
            bracket(active, isActive: true)
        }
    }

    /// All saved markers as pins dropping from the top — a round head on a short stem.
    ///
    /// Polish pass (ADR 0018 follow-up): the head is a touch larger (6 pt) with a
    /// rounded stem cap, and a near-background halo rings the head and backs the stem
    /// so a purple pin stays crisp where it crosses bright bars near the top edge.
    private func drawMarkerPins(in context: GraphicsContext, size: CGSize,
                                atX: (Double) -> CGFloat) {
        let stemHeight: CGFloat = 11
        let headRadius: CGFloat = 3
        for fraction in markerFractions {
            let pinX = atX(fraction)
            guard pinX > -4, pinX < size.width + 4 else { continue }  // off-screen
            var stem = Path()
            stem.move(to: CGPoint(x: pinX, y: 0))
            stem.addLine(to: CGPoint(x: pinX, y: stemHeight))
            // Halo, then the purple stem — round caps on both.
            context.stroke(stem, with: .color(PocketColor.background.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            context.stroke(stem, with: .color(PocketColor.pin),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            let head = CGRect(x: pinX - headRadius, y: 0, width: headRadius * 2, height: headRadius * 2)
            context.fill(Path(ellipseIn: head.insetBy(dx: -1, dy: -1)),
                         with: .color(PocketColor.background.opacity(0.55)))
            context.fill(Path(ellipseIn: head), with: .color(PocketColor.pin))
        }
    }

    /// Faint vertical grid behind the bars (ADR 0022): a thin line per beat with the
    /// bar-start downbeats brighter and slightly heavier. Density-aware so a zoomed-out
    /// view doesn't smear into a wash — sub-beats drop out once they'd sit under ~5 pt
    /// apart, and the whole grid is skipped once even the downbeats would crowd.
    private func drawBeatGrid(in context: GraphicsContext, size: CGSize,
                              atX: (Double) -> CGFloat) {
        guard beats.count >= 2 else { return }
        let span = max(0.0001, viewport.end - viewport.start)
        let beatPx = size.width * abs(beats[1].fraction - beats[0].fraction) / span
        guard beatPx >= 1 else { return }          // even downbeats would crowd — no grid
        let showSubBeats = beatPx >= 5
        for beat in beats {
            guard beat.isDownbeat || showSubBeats else { continue }
            let lineX = atX(beat.fraction)
            guard lineX > -1, lineX < size.width + 1 else { continue }   // off-screen
            var line = Path()
            line.move(to: CGPoint(x: lineX, y: 0))
            line.addLine(to: CGPoint(x: lineX, y: size.height))
            let opacity = beat.isDownbeat ? 0.14 : 0.06
            context.stroke(line, with: .color(PocketColor.textPrimary.opacity(opacity)),
                           lineWidth: beat.isDownbeat ? 1 : 0.75)
        }
    }

    /// 0…1 position of a song fraction on the *visible* waveform (outside 0…1 when
    /// the song fraction is off-screen at the current zoom).
    private func screenX(_ songFraction: Double) -> Double {
        WaveformGesture.screenFraction(songFraction: songFraction, viewport: viewport)
    }

    /// A touch's x (points) → song fraction, mapped through the zoom viewport.
    /// Not `private` — the gesture recogniser extension (other file) maps through it.
    func songFraction(atX point: CGFloat, width: CGFloat) -> Double {
        WaveformGesture.songFraction(
            screenFraction: WaveformGesture.fraction(atX: point, width: width),
            viewport: viewport)
    }

    /// X for the time bubble — the playhead position, clamped so the bubble
    /// stays fully on-screen at either edge.
    private func bubbleX(width: CGFloat) -> CGFloat {
        let half: CGFloat = 28
        return min(max(half, width * CGFloat(screenX(playheadFraction))), width - half)
    }
}

/// Small mono time readout pinned above the playhead (brief §3.2 — mono time).
private struct TimeBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.pocketMono(.caption2))
            .foregroundStyle(PocketColor.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(PocketColor.background.opacity(0.85))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
            )
    }
}

/// Light haptic for gesture confirmations — no-op where UIKit is unavailable.
@MainActor func haptic(_ style: HapticStyle) {
    #if canImport(UIKit)
    UIImpactFeedbackGenerator(style: style.uiStyle).impactOccurred()
    #endif
}

enum HapticStyle {
    case light, medium
    #if canImport(UIKit)
    var uiStyle: UIImpactFeedbackGenerator.FeedbackStyle { self == .light ? .light : .medium }
    #endif
}

// Minimap (item 7) lives in `WaveformMinimap.swift`.
