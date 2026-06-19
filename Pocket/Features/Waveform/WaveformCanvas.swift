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
/// - **Navigate** (default): tap → seek the playhead; drag → scrub; pinch → zoom.
/// - **Fine:** drag the two blue handles to set the loop bounds.
///
/// Marker drop and loop punch are *not* gestures — they're buttons on the transport
/// action bar (they act at the playhead). All gesture math (point → fraction, zoom
/// viewport, handle hit-testing) lives in the pure, unit-tested `WaveformGesture`;
/// the view emits *song fractions* (0…1) so the parent never deals in points.
struct WaveformView: View {
    let amplitudes: [Double]
    let playheadFraction: Double
    let loop: Loop?
    /// Every saved loop on the song — drawn as lane-stacked brackets along the
    /// bottom so the whole loop library reads against the timeline, not just the
    /// active one. Overlap is shown by lane (vertical position); colour stays
    /// reserved for state (the active loop's bracket is brighter). See ADR 0018.
    let loops: [Loop]
    /// Saved markers as song fractions (0…1) — drawn as pins dropping from the top.
    let markerFractions: [Double]
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
    /// Pinch-to-zoom: the visible window of the song (song fractions). Both the
    /// rendering and the touch→song-fraction mapping go through it.
    let viewport: (start: Double, end: Double)
    /// Pinch magnification → set the new zoom span (visible fraction of the song).
    let onSetZoomSpan: (Double) -> Void

    // Gesture bookkeeping.
    @State private var dragStartX: CGFloat?
    @State private var didScrub = false                     // moved enough to be a scrub (not a tap)
    @State private var grabbedHandle: WaveformGesture.Handle?  // Fine mode
    @State private var pinchBaseSpan: Double?               // zoom span captured at pinch start

    private let scrubThreshold: CGFloat = 6                 // px before a press counts as a scrub vs a tap
    private let handleTolerance = 0.06                      // fraction either side of a handle that grabs it

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
        guard !amplitudes.isEmpty else { return }
        let count = amplitudes.count
        let span = max(0.0001, viewport.end - viewport.start)
        let barSpacing: CGFloat = 1
        let pitch = size.width / (CGFloat(count) * CGFloat(span))   // on-screen distance between bars
        let barWidth = max(1, pitch - barSpacing)
        let midY = size.height / 2
        // Song fraction → on-screen x (through the zoom viewport).
        func atX(_ songFraction: Double) -> CGFloat { CGFloat(screenX(songFraction)) * size.width }
        let playheadX = atX(playheadFraction)

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

        drawBars(in: context, size: size, barWidth: barWidth, midY: midY, playheadX: playheadX)

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

    /// Mirrored bars for the visible slice of the song, stretched to fill the width.
    private func drawBars(in context: GraphicsContext, size: CGSize,
                          barWidth: CGFloat, midY: CGFloat, playheadX: CGFloat) {
        let count = amplitudes.count
        for (index, amp) in amplitudes.enumerated() {
            let barX = CGFloat(screenX(Double(index) / Double(count))) * size.width
            guard barX > -barWidth, barX < size.width else { continue }   // off-screen
            let color = barX <= playheadX ? PocketColor.barPlayed : PocketColor.barDefault
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
    private static let bracketFoot: CGFloat = 5

    /// All saved loops as lane-stacked brackets along the bottom. Overlap is shown
    /// by lane; colour is reserved for state — the active loop's bracket is full
    /// amber, the rest are dimmed. The active loop is drawn last so it stays on top.
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

            var path = Path()
            path.move(to: CGPoint(x: max(0, startX), y: baseY))
            path.addLine(to: CGPoint(x: min(size.width, endX), y: baseY))
            // Feet point up at the *true* ends — only where the end is on-screen.
            if startX >= 0 {
                path.move(to: CGPoint(x: startX, y: baseY))
                path.addLine(to: CGPoint(x: startX, y: baseY - Self.bracketFoot))
            }
            if endX <= size.width {
                path.move(to: CGPoint(x: endX, y: baseY))
                path.addLine(to: CGPoint(x: endX, y: baseY - Self.bracketFoot))
            }
            let color = PocketColor.marker.opacity(isActive ? 1.0 : 0.5)
            context.stroke(path, with: .color(color), lineWidth: isActive ? 2 : 1.5)
        }

        let activeUID = loop?.uid
        for loop in loops where loop.uid != activeUID { bracket(loop, isActive: false) }
        if let active = loop, loops.contains(where: { $0.uid == active.uid }) {
            bracket(active, isActive: true)
        }
    }

    /// All saved markers as pins dropping from the top — a dot head with a short stem.
    private func drawMarkerPins(in context: GraphicsContext, size: CGSize,
                                atX: (Double) -> CGFloat) {
        let stemHeight: CGFloat = 10
        for fraction in markerFractions {
            let pinX = atX(fraction)
            guard pinX > -3, pinX < size.width + 3 else { continue }  // off-screen
            var stem = Path()
            stem.move(to: CGPoint(x: pinX, y: 0))
            stem.addLine(to: CGPoint(x: pinX, y: stemHeight))
            context.stroke(stem, with: .color(PocketColor.pin), lineWidth: 1.5)
            context.fill(Path(ellipseIn: CGRect(x: pinX - 2.5, y: 0, width: 5, height: 5)),
                         with: .color(PocketColor.pin))
        }
    }

    /// 0…1 position of a song fraction on the *visible* waveform (outside 0…1 when
    /// the song fraction is off-screen at the current zoom).
    private func screenX(_ songFraction: Double) -> Double {
        WaveformGesture.screenFraction(songFraction: songFraction, viewport: viewport)
    }

    /// A touch's x (points) → song fraction, mapped through the zoom viewport.
    private func songFraction(atX point: CGFloat, width: CGFloat) -> Double {
        WaveformGesture.songFraction(
            screenFraction: WaveformGesture.fraction(atX: point, width: width),
            viewport: viewport)
    }

    /// Pinch to set the zoom span — `MagnifyGesture` (iOS 17+). The span at pinch
    /// start is captured so the magnification scales it directly.
    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = pinchBaseSpan ?? (viewport.end - viewport.start)
                pinchBaseSpan = base
                onSetZoomSpan(WaveformGesture.clampSpan(base / value.magnification))
            }
            .onEnded { _ in pinchBaseSpan = nil }
    }

    // MARK: Gesture

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in handleChanged(value, width: width) }
            .onEnded { value in handleEnded(value, width: width) }
    }

    private func handleChanged(_ value: DragGesture.Value, width: CGFloat) {
        guard pinchBaseSpan == nil else { return }   // ignore the drag while pinching
        let fraction = songFraction(atX: value.location.x, width: width)
        if dragStartX == nil {
            dragStartX = value.startLocation.x
            didScrub = false
            if mode == .fine { grabbedHandle = pickHandle(at: fraction) }
        }
        let moved = abs(value.location.x - (dragStartX ?? value.location.x))
        switch mode {
        case .navigate:
            if didScrub || moved > scrubThreshold {     // a real drag scrubs the playhead
                didScrub = true
                onScrub(fraction)
            }
        case .fine:
            if let grabbedHandle { onMoveHandle(grabbedHandle, fraction) }
        }
    }

    private func handleEnded(_ value: DragGesture.Value, width: CGFloat) {
        guard pinchBaseSpan == nil else { dragStartX = nil; return }
        let fraction = songFraction(atX: value.location.x, width: width)
        let moved = abs(value.location.x - (dragStartX ?? value.location.x))
        switch mode {
        case .navigate:
            if !didScrub && moved <= scrubThreshold { onSeek(fraction) }   // a tap = seek
        case .fine:
            if grabbedHandle != nil { onMoveHandleEnded() }   // audition the new bounds
            grabbedHandle = nil
        }
        dragStartX = nil
    }

    /// X for the time bubble — the playhead position, clamped so the bubble
    /// stays fully on-screen at either edge.
    private func bubbleX(width: CGFloat) -> CGFloat {
        let half: CGFloat = 28
        return min(max(half, width * CGFloat(screenX(playheadFraction))), width - half)
    }

    /// Which Fine handle a touch grabs — defaults to `.start` when there's no
    /// selection yet, so the first drag always moves something.
    private func pickHandle(at fraction: Double) -> WaveformGesture.Handle {
        guard let fineSelection else { return .start }
        // Tolerance is a song fraction; scale by the zoom span so the grab zone
        // stays a constant size on screen.
        let tolerance = handleTolerance * (viewport.end - viewport.start)
        return WaveformGesture.nearestHandle(toFraction: fraction,
                                             start: fineSelection.start, end: fineSelection.end,
                                             tolerance: tolerance)
            ?? (abs(fraction - fineSelection.start) <= abs(fraction - fineSelection.end) ? .start : .end)
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
