import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// The custom-drawn parts of the waveform practice screen (brief §4.1, items 5
// and 7). Kept separate from the declarative layout sections because this is
// imperative Canvas drawing — a different category of code.

// MARK: - 5. Waveform — SoundCloud-style mirrored bars + gesture engine

/// The detail waveform. Renders the mirrored bars, the active loop region, the live
/// A/B span + its handles, and the playhead (brief §4.1 / ADR 0005, 0041):
///
/// - tap → seek · drag → scrub · **hold-drag → set an A/B span** · pinch → zoom.
/// - Once a span is set, drag its **A / B handles** to refine it in place; drag a
///   saved loop's edge to lift it back into A/B for a range edit.
///
/// Marker drop and the A/B set control are also buttons on the transport bar (they
/// act at the playhead). All gesture math (point → fraction, zoom
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
    /// A/B forming: point **A** is placed and awaiting B. The region from here to the
    /// live playhead fills green as playback runs forward to find B (ADR 0041).
    let formingStart: Double?
    /// The set A/B span's region — a static green wash so it stays visible while you
    /// rehearse / adjust it (ADR 0041).
    let tapSelection: (start: Double, end: Double)?
    /// The set A/B span (ADR 0041) — drawn with labelled A/B handles you drag to refine
    /// in place (navigate mode, no mode hop); `nil` unless a span is closed.
    var abSelection: (start: Double, end: Double)?
    /// Live playhead time, shown in a bubble pinned to the playhead.
    let playheadLabel: String

    let onSeek: (Double) -> Void
    let onScrub: (Double) -> Void
    /// Drag / release of an A/B span handle (ADR 0041) — drag an A or B edge in place,
    /// no mode hop; release passes the moved handle.
    var onMoveABHandle: (WaveformGesture.Handle, Double) -> Void = { _, _ in }
    var onMoveABHandleEnded: (WaveformGesture.Handle) -> Void = { _ in }
    /// Grabbed the active loop's edge (ADR 0041) — lift it into the A/B span to range-edit.
    var onLiftLoopEdge: () -> Void = {}
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
    /// A finger landed on / lifted off the waveform — brackets every touch so the
    /// screen can suppress the swipe-back during a scrub (ADR 0030). Defaulted so the
    /// component previews/call sites that don't care opt out for free.
    var onTouchBegan: () -> Void = {}
    var onTouchEnded: () -> Void = {}

    // Gesture bookkeeping. Not `private` — the gesture recogniser lives in a
    // `WaveformView` extension in `WaveformCanvasGestures.swift`, so it reads this
    // state across files within the module.
    @State var dragStartX: CGFloat?
    @State var didScrub = false                     // moved enough to be a scrub (not a tap)
    @State var grabbedHandle: WaveformGesture.Handle?  // a committed A/B-edge drag
    @State var grabbedHandleOrigin: Double?            // its value at grab-time, to revert on a pinch takeover
    /// A loop edge touched but not yet committed to a drag (ADR 0041): a **tap** here
    /// seeks the playhead; only movement past the scrub threshold commits to dragging the
    /// edge (lifting a saved loop into A/B first when `lift`). Lets you tap-seek inside a
    /// loop — even a short one whose edge grab-zones cover it — without nudging a handle.
    @State var pendingGrab: (handle: WaveformGesture.Handle, lift: Bool)?
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
                    // Low in the bar region: clears the mid-height handles + the loop band below.
                    .position(x: bubbleX(width: geo.size.width), y: geo.size.height - Self.loopBand - 12)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(width: geo.size.width))
            .simultaneousGesture(magnifyGesture)
        }
        .frame(height: 140)
        .accessibilityElement()
        .accessibilityLabel("Waveform")
        .accessibilityHint("Tap to seek, drag to scrub, hold-drag to set a loop, pinch to zoom")
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
        // Suppressed while a span is up (`tapSelection`), so a lifted range edit shows the
        // single A/B wash, not a muddy double tint (ADR 0041).
        if let loop, tapSelection == nil {
            context.fill(Path(regionRect(loop.start, loop.end)),
                         with: .color(loopColor(for: loop).opacity(0.14)))
        }

        // Forming A/B span — A is placed, B pending: fill from A to the live playhead
        // as playback runs forward to find B (ADR 0041).
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

        drawBars(in: context, size: size, barSet: barSet, playheadX: playheadX, region: region)

        // Beat grid ON TOP of the bars (ADR 0022; restyled ADR 0024 follow-up) so each
        // line reads consistently instead of being unevenly occluded by tall bars.
        drawBeatGrid(in: context, size: size, atX: atX, region: region)

        // Annotations on the borders (ADR 0023): per-loop coloured lines along the
        // bottom (lane-stacked), purple inverted triangles along the top.
        drawLoopLines(in: context, size: size, atX: atX)
        drawMarkerTriangles(in: context, size: size, atX: atX)

        // Handles in front of the bars (helpers in `WaveformDownbeat.swift`): A/B span
        // handles, plus grabbable edges on the active loop.
        drawABHandles(in: context, region: region, atX: atX)   // A/B span handles (ADR 0041)
        if let loop {                                          // grabbable edges on the active loop (ADR 0041)
            drawLoopEditHandles(in: context, region: region, atX: atX, loop: loop, color: loopColor(for: loop))
        }

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
    static let markerBand: CGFloat = 16             // top: marker triangles (used by the helpers file)
    private static let loopBand: CGFloat = 24       // bottom: loop lines (maxLanes × laneHeight + pad)
    // Loop lines stack upward from the bottom edge. Capped at `maxLanes` so deep
    // nesting can't march up out of the band — anything deeper clamps into the last lane.
    private static let maxLanes = 3
    private static let laneHeight: CGFloat = 7
    private static let bracketPadding: CGFloat = 3

    /// The identity colour for a loop (ADR 0023) — shared via `LoopColor` so the
    /// waveform, minimap, and transport strip all resolve the same hue.
    private func loopColor(for loop: Loop) -> Color { LoopColor.color(for: loop, among: loops) }

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

    /// Vertical beat grid drawn **on top of** the bars (ADR 0022; restyled ADR 0024) so
    /// each line is full-height instead of unevenly occluded. Bar-start **downbeats** get
    /// a dark halo + brighter line (ADR 0023 halo); sub-beats a fainter line that drops
    /// out under ~5 pt apart, with the whole grid skipped once even downbeats would crowd.
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

    /// X for the time bubble — the playhead position, clamped fully on-screen either edge.
    private func bubbleX(width: CGFloat) -> CGFloat {
        let half: CGFloat = 28
        return min(max(half, width * CGFloat(screenX(playheadFraction))), width - half)
    }
}

// Minimap (item 7) lives in `WaveformMinimap.swift`.
// Haptic helpers live in `Haptics.swift`.
