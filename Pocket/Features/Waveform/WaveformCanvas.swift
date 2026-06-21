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
    /// Every saved loop on the song — drawn as lane-stacked coloured lines along the
    /// bottom border so the whole loop library reads against the timeline, not just
    /// the active one. Overlap is shown by lane (vertical position); colour encodes
    /// loop *identity* (each loop its own hue), with state carried by line weight.
    /// See ADR 0023 (supersedes ADR 0018's colour-is-state rule).
    let loops: [Loop]
    /// Saved markers as song fractions (0…1) — drawn as purple inverted triangles
    /// along the top border (ADR 0023).
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

    /// "Set the 1 on the waveform" (ADR 0024): the downbeat fraction being placed, or
    /// `nil` when not in downbeat mode. When set, a labelled "1" handle is drawn here
    /// and any drag on the waveform moves it (snapped on release) instead of seeking.
    var downbeatDraft: Double?
    /// Live drag of the downbeat handle → this fraction (raw, tracks the finger).
    var onDownbeatMove: (Double) -> Void = { _ in }
    /// The downbeat drag released — snap to the nearest transient peak.
    var onDownbeatEnded: () -> Void = {}

    // Gesture bookkeeping. Not `private` — the gesture recogniser lives in a
    // `WaveformView` extension in `WaveformCanvasGestures.swift`, so it reads this
    // state across files within the module.
    @State var dragStartX: CGFloat?
    @State var didScrub = false                     // moved enough to be a scrub (not a tap)
    @State var grabbedHandle: WaveformGesture.Handle?  // Fine mode
    @State var grabbedHandleOrigin: Double?            // its value at grab-time, to revert on a pinch takeover
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
                // Live time bubble, pinned to the playhead and vertically centred,
                // clamped so it never runs off either edge.
                TimeBubble(text: playheadLabel)
                    .position(x: bubbleX(width: geo.size.width), y: geo.size.height / 2)
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
        // Annotation border bands (ADR 0023): markers in a top band, loop lines in a
        // bottom band, so the bars in the middle read clean. Bars fill the region between.
        let region = BarRegion(top: Self.markerBand, bottom: size.height - Self.loopBand)
        // Song fraction → on-screen x (through the zoom viewport).
        func atX(_ songFraction: Double) -> CGFloat { CGFloat(screenX(songFraction)) * size.width }
        let playheadX = atX(playheadFraction)

        // A filled rect spanning the bar region between two song fractions.
        func regionRect(_ from: Double, _ upTo: Double) -> CGRect {
            let startX = atX(from)
            return CGRect(x: startX, y: region.top, width: atX(upTo) - startX, height: region.height)
        }

        // Active loop region — tinted the active loop's own identity colour (ADR 0023).
        if let loop {
            context.fill(Path(regionRect(loop.start, loop.end)),
                         with: .color(loopColor(for: loop).opacity(0.14)))
        }

        // Forming loop (Tap mode) — fills with the playing colour from the start to
        // the playhead as playback previews the section being captured.
        if let formingStart {
            context.fill(Path(regionRect(min(formingStart, playheadFraction),
                                         max(formingStart, playheadFraction))),
                         with: .color(PocketColor.active.opacity(0.22)))
        }

        // Captured Tap loop awaiting confirm — static highlight in the playing colour.
        if let tapSelection {
            context.fill(Path(regionRect(tapSelection.start, tapSelection.end)),
                         with: .color(PocketColor.active.opacity(0.22)))
        }

        // Fine selection wash — behind the bars, like the other region tints. The
        // draggable handles draw *in front* of the bars below (so they aren't occluded).
        if let fineSelection {
            context.fill(Path(regionRect(fineSelection.start, fineSelection.end)),
                         with: .color(PocketColor.fine.opacity(0.18)))
        }

        drawBars(in: context, size: size, barSet: barSet, playheadX: playheadX, region: region)

        // Beat grid ON TOP of the bars (ADR 0022; restyled ADR 0024 follow-up) so each
        // line reads consistently instead of being unevenly occluded by tall bars.
        drawBeatGrid(in: context, size: size, atX: atX, region: region)

        // Annotations on the borders (ADR 0023): per-loop coloured lines along the
        // bottom (lane-stacked), purple inverted triangles along the top.
        drawLoopLines(in: context, size: size, atX: atX)
        drawMarkerTriangles(in: context, size: size, atX: atX)

        // Fine handles in front of the bars (helper in `WaveformDownbeat.swift`, ADR 0023
        // follow-up); the wash already went down behind the bars above.
        drawFineHandles(in: context, region: region, atX: atX)

        // Playhead.
        var line = Path()
        line.move(to: CGPoint(x: playheadX, y: 0))
        line.addLine(to: CGPoint(x: playheadX, y: size.height))
        context.stroke(line, with: .color(PocketColor.textPrimary.opacity(0.8)), lineWidth: 1.5)

        // Downbeat handle on top of everything while placing the 1 (ADR 0024). The
        // drawing helper lives in `WaveformDownbeat.swift` (file-length budget).
        if let downbeatDraft {
            drawDownbeatHandle(in: context, size: size, atX: atX(downbeatDraft))
        }
    }

    /// Mirrored bars for the visible slice of the song. `barSet` either covers the
    /// whole song (`[0, 1]`, stretched through the viewport) or just the zoomed window
    /// (crisp re-downsample, ADR 0020); each bar is placed at its centre within the
    /// range it covers, then mapped through the viewport.
    private func drawBars(in context: GraphicsContext, size: CGSize,
                          barSet: WaveformDetailBars, playheadX: CGFloat, region: BarRegion) {
        let count = barSet.bars.count
        guard count > 0 else { return }
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
            let topHeight = CGFloat(amp) * region.scale
            context.fill(Path(CGRect(x: barX, y: region.axis - topHeight, width: barWidth, height: topHeight)),
                         with: .color(color))
            // Reflection at ~60% — brief §4.1.
            context.fill(Path(CGRect(x: barX, y: region.axis, width: barWidth, height: topHeight * 0.6)),
                         with: .color(color.opacity(0.6)))
        }
    }

    /// The vertical band the bars occupy, between the marker (top) and loop (bottom)
    /// border bands. `axis`/`scale` place the mirror so a full bar plus its 60%
    /// reflection exactly fills the region (ADR 0023).
    struct BarRegion {
        let top: CGFloat
        let bottom: CGFloat
        var height: CGFloat { bottom - top }
        var scale: CGFloat { max(1, height / 1.6) }
        var axis: CGFloat { top + scale }
        var midY: CGFloat { (top + bottom) / 2 }
    }

    // Border bands (ADR 0023): annotations sit on the borders, off the bars. The
    // top band holds marker triangles; the bottom band holds lane-stacked loop
    // lines. The bars are drawn in the region between them.
    private static let markerBand: CGFloat = 16     // top: marker triangles
    private static let loopBand: CGFloat = 24       // bottom: loop lines (maxLanes × laneHeight + pad)
    // Loop lines stack upward from the bottom edge. Capped at `maxLanes` so deep
    // nesting can't march up out of the band — anything deeper clamps into the last lane.
    private static let maxLanes = 3
    private static let laneHeight: CGFloat = 7
    private static let bracketPadding: CGFloat = 3

    /// The identity colour for a loop (ADR 0023): a deterministic palette slot by
    /// start-order, so each loop reads as its own hue. Overlap is still shown by lane.
    private func loopColor(for loop: Loop) -> Color {
        let intervals = loops.map { LoopLanes.Interval(id: $0.uid, start: $0.start, end: $0.end) }
        let slot = LoopColors.slot(for: loop.uid, among: intervals,
                                   paletteCount: PocketColor.loopPalette.count)
        return PocketColor.loopPalette[slot]
    }

    /// All saved loops as lane-stacked horizontal lines along the bottom border.
    /// Colour encodes loop **identity** (ADR 0023, superseding ADR 0018's
    /// colour-is-state rule); overlap is shown by lane. State is carried by weight
    /// and opacity instead — the active loop is heavier (2.5 pt, full opacity), the
    /// rest dimmed (1.5 pt, 0.55). A near-background halo lifts each line off the
    /// background. The active loop is drawn last so it stays on top.
    private func drawLoopLines(in context: GraphicsContext, size: CGSize,
                               atX: (Double) -> CGFloat) {
        guard !loops.isEmpty else { return }
        let packing = LoopLanes.pack(loops.map {
            LoopLanes.Interval(id: $0.uid, start: $0.start, end: $0.end)
        })

        func line(_ loop: Loop, isActive: Bool) {
            let startX = atX(loop.start)
            let endX = atX(loop.end)
            guard endX > 0, startX < size.width else { return }       // off-screen
            let lane = min(packing.lane(for: loop.uid), Self.maxLanes - 1)
            let baseY = size.height - Self.bracketPadding - CGFloat(lane) * Self.laneHeight

            var path = Path()
            path.move(to: CGPoint(x: max(0, startX), y: baseY))
            path.addLine(to: CGPoint(x: min(size.width, endX), y: baseY))
            let width: CGFloat = isActive ? 2.5 : 1.5
            // Contrast halo behind, then the loop's identity colour. Round caps.
            context.stroke(path, with: .color(PocketColor.background.opacity(0.55)),
                           style: StrokeStyle(lineWidth: width + 1.5, lineCap: .round))
            context.stroke(path, with: .color(loopColor(for: loop).opacity(isActive ? 1.0 : 0.55)),
                           style: StrokeStyle(lineWidth: width, lineCap: .round))
        }

        let activeUID = loop?.uid
        for loop in loops where loop.uid != activeUID { line(loop, isActive: false) }
        if let active = loop, loops.contains(where: { $0.uid == active.uid }) {
            line(active, isActive: true)
        }
    }

    /// All saved markers as purple inverted triangles along the top border, apex
    /// pointing down at the marker position (ADR 0023 — replaces the stem+dot pin).
    /// A near-background halo keeps the triangle crisp, and a short tick drops from
    /// the apex into the bar region to pin the exact location.
    private func drawMarkerTriangles(in context: GraphicsContext, size: CGSize,
                                     atX: (Double) -> CGFloat) {
        let halfWidth: CGFloat = 3.5
        let triHeight: CGFloat = 6
        let apexY = Self.markerBand - 3        // apex sits just above the bars
        let topY = apexY - triHeight
        for fraction in markerFractions {
            let pinX = atX(fraction)
            guard pinX > -halfWidth, pinX < size.width + halfWidth else { continue }  // off-screen
            var triangle = Path()
            triangle.move(to: CGPoint(x: pinX - halfWidth, y: topY))
            triangle.addLine(to: CGPoint(x: pinX + halfWidth, y: topY))
            triangle.addLine(to: CGPoint(x: pinX, y: apexY))
            triangle.closeSubpath()
            // Halo outline behind, then the purple fill.
            context.stroke(triangle, with: .color(PocketColor.background.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            context.fill(triangle, with: .color(PocketColor.pin))
            // Precision tick from the apex into the bar region.
            var tick = Path()
            tick.move(to: CGPoint(x: pinX, y: apexY))
            tick.addLine(to: CGPoint(x: pinX, y: apexY + 3))
            context.stroke(tick, with: .color(PocketColor.pin.opacity(0.6)), lineWidth: 1)
        }
    }

    /// Vertical beat grid drawn **on top of** the bars (ADR 0022; restyled ADR 0024
    /// follow-up). Drawing behind the bars let tall bars occlude the lines unevenly, so
    /// some downbeats "stuck out" more than others; on top, each line is full-height and
    /// consistent. Bar-start **downbeats** get a dark halo + brighter line (the ADR 0023
    /// halo trick) so they read over both the bright blue bars and the dark gaps;
    /// sub-beats stay a fainter plain line. Density-aware: sub-beats drop out under ~5 pt
    /// apart, and the whole grid is skipped once even the downbeats would crowd.
    private func drawBeatGrid(in context: GraphicsContext, size: CGSize,
                              atX: (Double) -> CGFloat, region: BarRegion) {
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
            line.move(to: CGPoint(x: lineX, y: region.top))
            line.addLine(to: CGPoint(x: lineX, y: region.bottom))
            if beat.isDownbeat {
                // A *soft* halo (not the full ADR 0023 strength) gives the line even
                // contrast over bright bars and dark gaps without making it pop, then a
                // low-opacity line keeps it noticeable-but-quiet.
                context.stroke(line, with: .color(PocketColor.background.opacity(0.09)), lineWidth: 1.5)
                context.stroke(line, with: .color(PocketColor.textPrimary.opacity(0.07)), lineWidth: 1)
            } else {
                context.stroke(line, with: .color(PocketColor.textPrimary.opacity(0.04)), lineWidth: 0.75)
            }
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

// Minimap (item 7) lives in `WaveformMinimap.swift`.
// Haptic helpers live in `Haptics.swift`.
