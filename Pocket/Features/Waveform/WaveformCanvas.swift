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
/// - Once a span is set, drag its **A / B handles** to refine it in place. A saved
///   loop's edge is *not* directly draggable here — that only happens via the loop's
///   edit sheet's explicit "Adjust range on waveform", so a stray touch can't resize it.
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

/// A saved marker for the waveform: its song-fraction position (0…1) plus its label.
/// The position feeds the top-border triangles / cluster chips; the label surfaces as
/// a single floating chip when the playhead draws near (P2 — one active label at a time).
struct WaveformMarker: Equatable {
    let fraction: Double
    let label: String
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
    /// Saved markers (position + label) — drawn as purple inverted triangles along the
    /// top border (ADR 0023), merging into a count chip where they collide at low zoom,
    /// with the nearest-the-playhead marker's label floating as a chip (P2).
    let markers: [WaveformMarker]
    /// The beat grid (ADR 0022): beats + bar-start downbeats as song fractions, drawn
    /// faintly behind the bars (downbeats brighter). Empty when the song has no tempo
    /// or no downbeat anchor, so the whole grid simply doesn't render. Defaulted so
    /// the many component previews/call sites that don't care opt out for free.
    var beats: [BeatGrid.Beat] = []
    /// Whether the beat grid is *drawn* (ADR 0051). `beats` still feed snap candidates when
    /// off, so gating happens at draw time — not by emptying `beats`.
    var showsGrid = true
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
    /// When true the waveform flexes to fill the available vertical space instead of its
    /// fixed portrait height — landscape gives it the leftover room so the transport still
    /// pins to the bottom (ADR 0042). The canvas is geometry-driven, so it adapts for free.
    var fillsHeight: Bool = false
    /// Whether the active marker's label floats over the timeline (P2 setting, default on).
    /// Off ⇒ triangles / count chips still draw, but labels live only in the Markers panel.
    var showsMarkerLabels: Bool = true

    // Gesture bookkeeping. Not `private` — the gesture recogniser lives in a
    // `WaveformView` extension in `WaveformCanvasGestures.swift`, so it reads this
    // state across files within the module.
    @State var dragStartX: CGFloat?
    @State var didScrub = false                     // moved enough to be a scrub (not a tap)
    @State var grabbedHandle: WaveformGesture.Handle?  // a committed A/B-edge drag
    @State var grabbedHandleOrigin: Double?            // its value at grab-time, to revert on a pinch takeover
    /// An A/B span edge touched but not yet committed to a drag (ADR 0041): a **tap**
    /// here seeks the playhead; only movement past the scrub threshold commits to
    /// dragging the edge. Lets you tap-seek inside a span without nudging a handle.
    @State var pendingGrab: WaveformGesture.Handle?
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
        .frame(minHeight: fillsHeight ? 120 : 140, maxHeight: fillsHeight ? .infinity : 140)
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

        // Beat grid BEHIND the bars (ADR 0022; ADR 0049 follow-up). On top (ADR 0024) it cut
        // visibly across the now fuller, calmer waveform; behind, the opaque bars occlude it in
        // the played section so it reads only through the gaps.
        drawBeatGrid(in: context, size: size, atX: atX, region: region)

        drawBars(in: context, size: size, barSet: barSet, playheadX: playheadX, region: region)

        // Bold boundary lines at the active loop's edges, cut right across the bars
        // (ADR 0041 follow-up) — a static echo of the visual emphasis the old grabbable
        // edge knobs gave, so the loop's range still reads clearly on the waveform
        // itself even though the edges aren't draggable here (only via the edit sheet's
        // "Adjust range on waveform"). Suppressed alongside the wash while a span is up.
        if let loop, tapSelection == nil {
            drawLoopBoundaryLines(in: context, region: region, atX: atX, loop: loop)
        }

        // Annotations on the borders (ADR 0023): per-loop coloured lines along the
        // bottom (lane-stacked), purple inverted triangles along the top.
        drawLoopLines(in: context, size: size, atX: atX)
        drawMarkers(in: context, size: size, atX: atX)

        // A/B span handles in front of the bars (helper in `WaveformDownbeat.swift`). The
        // active loop's edges are *not* drawn as handles — they're no longer directly
        // draggable, so a knob there would promise an interaction that doesn't exist.
        drawABHandles(in: context, region: region, atX: atX)

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
        let sourceCount = barSet.bars.count
        guard sourceCount > 0 else { return }
        let span = max(0.0001, viewport.end - viewport.start)
        // On-screen distance between source bars: each covers (covered span)/count of the
        // song, and the viewport's span maps to the full width.
        let sourcePitch = size.width * CGFloat(barSet.end - barSet.start) / (CGFloat(sourceCount) * CGFloat(span))
        // Group thin bars into fewer, wider ones toward a target width — widens *and* smooths
        // the 1px comb (ADR 0049). No-op once bars are already wide enough (zoomed in), so deep
        // zoom keeps full detail.
        let group = WaveformBars.groupSize(sourcePitch: Double(sourcePitch), targetPitch: Self.targetBarPitch)
        let bars = WaveformBars.bucketedMean(barSet.bars, group: group)
        let count = bars.count
        let pitch = sourcePitch * CGFloat(group)
        let barWidth = max(1.5, pitch - Self.barGap)
        for (index, amp) in bars.enumerated() {
            let songFraction = WaveformGesture.barCentreFraction(
                index: index, count: count, coveredStart: barSet.start, coveredEnd: barSet.end)
            let barX = CGFloat(screenX(songFraction)) * size.width
            guard barX > -barWidth, barX < size.width else { continue }   // off-screen
            let color = barX <= playheadX ? PocketColor.waveformBarPlayed : PocketColor.waveformBar
            // Compress the normalised amplitude for a fuller, calmer skyline — display only,
            // the snap/marker math reads raw peaks elsewhere (ADR 0049).
            let topHeight = CGFloat(WaveformAmplitude.display(amp)) * region.scale
            let cap = barWidth / 2   // fully rounded ends soften the hard spiky tops (ADR 0049)
            // Main bar — rounded top, square at the axis so the baseline stays crisp.
            let topRect = CGRect(x: barX, y: region.axis - topHeight, width: barWidth, height: topHeight)
            context.fill(Path(roundedRect: topRect,
                              cornerRadii: RectangleCornerRadii(topLeading: cap, topTrailing: cap),
                              style: .continuous),
                         with: .color(color))
            // Reflection — a softened mirror (brief §4.1), rounded at its bottom.
            let reflectionRect = CGRect(x: barX, y: region.axis,
                                        width: barWidth, height: topHeight * Self.reflectionRatio)
            context.fill(Path(roundedRect: reflectionRect,
                              cornerRadii: RectangleCornerRadii(bottomLeading: cap, bottomTrailing: cap),
                              style: .continuous),
                         with: .color(color.opacity(Self.reflectionOpacity)))
        }
    }

    /// A bold vertical line at each of the active loop's edges, spanning the full bar
    /// region — see the call site's ADR 0041 follow-up note. In the loop's identity
    /// colour with a background halo, like the A/B handles' bar but without their
    /// pill/label knob, so it reads as a boundary marker rather than a grab target.
    private func drawLoopBoundaryLines(in context: GraphicsContext, region: BarRegion,
                                       atX: (Double) -> CGFloat, loop: Loop) {
        let color = loopColor(for: loop)
        for edgeX in [atX(loop.start), atX(loop.end)] {
            var line = Path()
            line.move(to: CGPoint(x: edgeX, y: region.top))
            line.addLine(to: CGPoint(x: edgeX, y: region.bottom))
            context.stroke(line, with: .color(PocketColor.background.opacity(0.6)), lineWidth: 3)
            context.stroke(line, with: .color(color), lineWidth: 1.5)
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

    // Bar drawing (ADR 0049). Thin ~1px bars read as a jittery comb; group source bars toward
    // this on-screen width for a calmer, chunkier skyline (with `barGap` between them).
    private static let targetBarPitch: Double = 4    // px: bar + gap the grouping aims for
    private static let barGap: CGFloat = 1.5         // px between drawn bars
    private static let reflectionRatio: CGFloat = 0.6   // mirror height as a fraction of the bar
    private static let reflectionOpacity: CGFloat = 0.3 // softened from 0.6 — a quieter mirror

    // Border bands (ADR 0023): annotations sit on the borders, off the bars. The
    // top band holds marker triangles; the bottom band holds lane-stacked loop
    // lines. The bars are drawn in the region between them.
    static let markerBand: CGFloat = 16             // top: marker triangles (used by the helpers file)
    static let loopBand: CGFloat = 24               // bottom: loop lines (maxLanes × laneHeight + pad;
                                                     // used by the helpers file too)

    // Marker labelling / clustering (P2; used by the drawing helpers file).
    static let markerHalfWidth: CGFloat = 3.5       // px: half a triangle, for off-screen culling
    static let markerClusterGap: CGFloat = 14       // px: triangles closer than this merge into a count chip
    static let markerLabelProximity: CGFloat = 44   // px from the playhead within which a marker's label shows

    /// The identity colour for a loop (ADR 0023) — shared via `LoopColor` so the
    /// waveform, minimap, and transport strip all resolve the same hue. Not `private` —
    /// `drawLoopLines` (file-length budget) lives in `WaveformDownbeat.swift`.
    func loopColor(for loop: Loop) -> Color { LoopColor.color(for: loop, among: loops) }

    /// Vertical beat grid drawn **behind** the bars (ADR 0022; restyled ADR 0024/0051) so
    /// the lines read through the gaps without cutting across the waveform. Only bar-start
    /// **downbeats** are drawn — sub-beat gridlines were dropped (ADR 0051) as they made
    /// zooming feel busy — and the whole grid is skipped once even downbeats would crowd.
    private func drawBeatGrid(in context: GraphicsContext, size: CGSize,
                              atX: (Double) -> CGFloat, region: BarRegion) {
        guard showsGrid, beats.count >= 2 else { return }
        let span = max(0.0001, viewport.end - viewport.start)
        let beatPx = size.width * abs(beats[1].fraction - beats[0].fraction) / span
        guard beatPx >= 1 else { return }          // even downbeats would crowd — no grid
        for beat in beats where beat.isDownbeat {
            let lineX = atX(beat.fraction)
            guard lineX > -1, lineX < size.width + 1 else { continue }   // off-screen
            // Stop at the baseline (`axis`) so no grid draws through the reflection (ADR 0049).
            var line = Path()
            line.move(to: CGPoint(x: lineX, y: region.top))
            line.addLine(to: CGPoint(x: lineX, y: region.axis))
            context.stroke(line, with: .color(PocketColor.gridLine), lineWidth: 1)
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
