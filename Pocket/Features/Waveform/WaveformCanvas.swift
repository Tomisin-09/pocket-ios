import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// The custom-drawn parts of the waveform practice screen (brief §4.1, items 5
// and 7). Kept separate from the declarative layout sections because this is
// imperative Canvas drawing — a different category of code.

// MARK: - 5. Waveform — SoundCloud-style mirrored bars + gesture engine

/// The detail waveform. Renders the mirrored bars, the active loop region, the
/// in-progress selection (Tap/Fine), the playhead, and the long-press ring; and
/// recognises the three interaction modes (brief §4.1):
///
/// - **Scroll:** tap → seek the playhead; hold 650 ms → drop a marker (an amber
///   ring fills under the finger first).
/// - **Tap:** drag → scrub; a short tap sets the loop start, a second tap closes
///   it. The in-progress selection draws green.
/// - **Fine:** drag the two blue handles to nudge the active selection's bounds.
///
/// All gesture math (point → fraction, bound ordering, handle hit-testing) lives
/// in the pure, unit-tested `WaveformGesture`. The view emits *fractions* (0…1)
/// so the parent screen never deals in points.
struct WaveformView: View {
    let amplitudes: [Double]
    let playheadFraction: Double
    let loop: WaveformMock.Loop?
    let mode: WaveformPracticeView.InteractionMode
    /// Tap mode: the start of the loop being captured. The region from here to
    /// the live playhead fills green as playback previews it.
    let formingStart: Double?
    /// Fine mode: the selection being dragged by the two blue handles.
    let fineSelection: (start: Double, end: Double)?
    /// Tap mode: the captured region awaiting confirm — a static green highlight
    /// so the punched loop stays visible while the confirm pill is up.
    let tapSelection: (start: Double, end: Double)?
    /// Live playhead time, shown in a bubble pinned to the playhead.
    let playheadLabel: String

    let onSeek: (Double) -> Void
    let onDropMarker: (Double) -> Void
    /// Tap mode: a location-less punch — marks the loop start/end at the *current
    /// playhead*, never at the tap position (only drag scrubs the playhead).
    let onTapPunch: () -> Void
    let onScrub: (Double) -> Void
    let onMoveHandle: (WaveformGesture.Handle, Double) -> Void
    /// Fine mode: the drag finished — commit the live audio preview to the new bounds.
    let onMoveHandleEnded: () -> Void

    // Gesture bookkeeping.
    @State private var dragStartX: CGFloat?
    @State private var didScrub = false                     // Tap mode: moved enough to be a scrub
    @State private var grabbedHandle: WaveformGesture.Handle?  // Fine mode
    @State private var holdTimer: Timer?
    @State private var holdFired = false                    // Scroll mode: hold already dropped a marker
    @State private var holdFraction: Double?                // where the ring draws
    @State private var holdProgress: CGFloat = 0            // 0…1 ring fill

    private let holdDuration = 0.65
    private let scrubThreshold: CGFloat = 6                 // px before a Tap-mode press counts as a scrub
    private let dragCancelsHold: CGFloat = 10               // px of movement that cancels a Scroll hold
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
                // Long-press ring (Scroll mode) — fills radially before the
                // marker drops, so the hold is legible (brief §4.1).
                if let holdFraction, holdProgress > 0 {
                    Circle()
                        .stroke(PocketColor.marker.opacity(0.85), lineWidth: 2)
                        .frame(width: 40, height: 40)
                        .scaleEffect(0.4 + holdProgress)
                        .opacity(Double(holdProgress))
                        .position(x: geo.size.width * holdFraction, y: geo.size.height / 2)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(width: geo.size.width))
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
        let barSpacing: CGFloat = 1
        let barWidth = max(1, (size.width - CGFloat(count - 1) * barSpacing) / CGFloat(count))
        let midY = size.height / 2
        let playheadX = size.width * playheadFraction

        // Active loop region (amber while paused — green is reserved for playing).
        if let loop {
            let rect = CGRect(x: size.width * loop.start, y: 0,
                              width: size.width * (loop.end - loop.start), height: size.height)
            context.fill(Path(rect), with: .color(PocketColor.marker.opacity(0.14)))
        }

        // Forming loop (Tap mode) — fills green from the start to the playhead as
        // playback previews the section being captured.
        if let formingStart {
            let lower = min(formingStart, playheadFraction)
            let upper = max(formingStart, playheadFraction)
            let rect = CGRect(x: size.width * lower, y: 0,
                              width: size.width * (upper - lower), height: size.height)
            context.fill(Path(rect), with: .color(PocketColor.active.opacity(0.22)))
        }

        // Captured Tap loop awaiting confirm — static green highlight.
        if let tapSelection {
            let rect = CGRect(x: size.width * tapSelection.start, y: 0,
                              width: size.width * (tapSelection.end - tapSelection.start), height: size.height)
            context.fill(Path(rect), with: .color(PocketColor.active.opacity(0.22)))
        }

        // Fine selection (blue region + two draggable handles).
        if let fineSelection {
            let startX = size.width * fineSelection.start
            let endX = size.width * fineSelection.end
            let rect = CGRect(x: startX, y: 0, width: endX - startX, height: size.height)
            context.fill(Path(rect), with: .color(PocketColor.fine.opacity(0.18)))
            for handleX in [startX, endX] {
                let bar = CGRect(x: handleX - 1.5, y: 0, width: 3, height: size.height)
                context.fill(Path(bar), with: .color(PocketColor.fine))
                let knob = CGRect(x: handleX - 5, y: midY - 9, width: 10, height: 18)
                context.fill(Path(roundedRect: knob, cornerRadius: 3), with: .color(PocketColor.fine))
            }
        }

        // Bars.
        for (index, amp) in amplitudes.enumerated() {
            let barX = CGFloat(index) * (barWidth + barSpacing)
            let played = barX <= playheadX
            let color = played ? PocketColor.barPlayed : PocketColor.barDefault
            let topHeight = CGFloat(amp) * midY
            let top = CGRect(x: barX, y: midY - topHeight, width: barWidth, height: topHeight)
            // Reflection at ~60% — brief §4.1.
            let bottom = CGRect(x: barX, y: midY, width: barWidth, height: topHeight * 0.6)
            context.fill(Path(top), with: .color(color))
            context.fill(Path(bottom), with: .color(color.opacity(0.6)))
        }

        // Playhead.
        var line = Path()
        line.move(to: CGPoint(x: playheadX, y: 0))
        line.addLine(to: CGPoint(x: playheadX, y: size.height))
        context.stroke(line, with: .color(PocketColor.textPrimary.opacity(0.8)), lineWidth: 1.5)
    }

    // MARK: Gesture

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in handleChanged(value, width: width) }
            .onEnded { value in handleEnded(value, width: width) }
    }

    private func handleChanged(_ value: DragGesture.Value, width: CGFloat) {
        let fraction = WaveformGesture.fraction(atX: value.location.x, width: width)
        let isFirst = dragStartX == nil
        if isFirst {
            dragStartX = value.startLocation.x
            didScrub = false
            switch mode {
            case .scroll: startHold(at: WaveformGesture.fraction(atX: value.startLocation.x, width: width))
            case .tap:    break
            case .fine:   grabbedHandle = pickHandle(at: fraction)
            }
        }

        let moved = abs(value.location.x - (dragStartX ?? value.location.x))
        switch mode {
        case .scroll:
            // A drag isn't a hold — cancel the marker timer and scrub instead.
            if didScrub || moved > dragCancelsHold {
                didScrub = true
                cancelHold()
                onScrub(fraction)
            }
        case .tap:
            if didScrub || moved > scrubThreshold {
                didScrub = true
                onScrub(fraction)
            }
        case .fine:
            if let grabbedHandle { onMoveHandle(grabbedHandle, fraction) }
        }
    }

    private func handleEnded(_ value: DragGesture.Value, width: CGFloat) {
        let fraction = WaveformGesture.fraction(atX: value.location.x, width: width)
        let moved = abs(value.location.x - (dragStartX ?? value.location.x))
        switch mode {
        case .scroll:
            cancelHold()
            if !holdFired && !didScrub && moved <= dragCancelsHold { onSeek(fraction) }  // a tap
        case .tap:
            if !didScrub && moved <= scrubThreshold {
                haptic(.light)
                onTapPunch()                                                  // punch in / out at the playhead
            }
        case .fine:
            if grabbedHandle != nil { onMoveHandleEnded() }   // audition the new bounds
            grabbedHandle = nil
        }
        dragStartX = nil
        holdFired = false
    }

    /// X for the time bubble — the playhead position, clamped so the bubble
    /// stays fully on-screen at either edge.
    private func bubbleX(width: CGFloat) -> CGFloat {
        let half: CGFloat = 28
        return min(max(half, width * playheadFraction), width - half)
    }

    /// Which Fine handle a touch grabs — defaults to `.start` when there's no
    /// selection yet, so the first drag always moves something.
    private func pickHandle(at fraction: Double) -> WaveformGesture.Handle {
        guard let fineSelection else { return .start }
        return WaveformGesture.nearestHandle(toFraction: fraction,
                                             start: fineSelection.start, end: fineSelection.end,
                                             tolerance: handleTolerance)
            ?? (abs(fraction - fineSelection.start) <= abs(fraction - fineSelection.end) ? .start : .end)
    }

    // MARK: Long press (Scroll mode marker drop)

    private func startHold(at fraction: Double) {
        holdFired = false
        holdFraction = fraction
        withAnimation(.linear(duration: holdDuration)) { holdProgress = 1 }
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { _ in
            Task { @MainActor in
                holdFired = true
                haptic(.medium)
                onDropMarker(fraction)
                holdFraction = nil
                holdProgress = 0
            }
        }
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        holdFraction = nil
        withAnimation(.easeOut(duration: 0.15)) { holdProgress = 0 }
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

// MARK: - 7. Minimap (full song, compressed)

struct Minimap: View {
    let song: WaveformMock.Song
    let activeLoop: WaveformMock.Loop?
    let markers: [WaveformMock.Marker]
    /// Fine-mode selection mirrored from the detail waveform (blue).
    let fineSelection: (start: Double, end: Double)?
    /// Live playhead position (0...1), driven by the audio engine.
    let playheadFraction: Double
    /// Tap or drag anywhere on the minimap to move the playhead.
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            canvas
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        onSeek(WaveformGesture.fraction(atX: value.location.x, width: geo.size.width))
                    }
                )
        }
        .frame(height: 28)
        .accessibilityElement()
        .accessibilityLabel("Song position")
        .accessibilityValue("\(Int((playheadFraction * 100).rounded()))%")
        .accessibilityHint("Adjust to move the playhead")
        .accessibilityAdjustableAction { direction in
            let step = 0.05
            switch direction {
            case .increment: onSeek(min(1, playheadFraction + step))
            case .decrement: onSeek(max(0, playheadFraction - step))
            @unknown default: break
            }
        }
    }

    private var canvas: some View {
        Canvas { context, size in
            // Base track.
            let base = CGRect(x: 0, y: size.height * 0.35, width: size.width, height: size.height * 0.3)
            context.fill(Path(roundedRect: base, cornerRadius: 2),
                         with: .color(PocketColor.barPlayed))

            // Loop region (amber).
            if let loop = activeLoop {
                let startX = size.width * loop.start
                let rect = CGRect(x: startX, y: 0, width: size.width * (loop.end - loop.start), height: size.height)
                context.fill(Path(roundedRect: rect, cornerRadius: 2),
                             with: .color(PocketColor.marker.opacity(0.5)))
            }

            // Fine selection (blue) — brief §4.1 minimap.
            if let fineSelection {
                let startX = size.width * fineSelection.start
                let rect = CGRect(x: startX, y: 0,
                                  width: size.width * (fineSelection.end - fineSelection.start),
                                  height: size.height)
                context.fill(Path(roundedRect: rect, cornerRadius: 2),
                             with: .color(PocketColor.fine.opacity(0.5)))
            }

            // Marker dots (purple).
            for marker in markers {
                let markerX = size.width * (marker.seconds / song.duration)
                let dot = CGRect(x: markerX - 2, y: size.height / 2 - 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: dot), with: .color(PocketColor.pin))
            }

            // Viewport indicator returns with pinch-to-zoom — until the detail
            // waveform can show a sub-slice, `song.viewport` is static, so drawing
            // the box just adds a meaningless rectangle. (Data kept in WaveformMock.)

            // Playhead.
            let playheadX = size.width * playheadFraction
            var line = Path()
            line.move(to: CGPoint(x: playheadX, y: 0))
            line.addLine(to: CGPoint(x: playheadX, y: size.height))
            context.stroke(line, with: .color(PocketColor.textPrimary.opacity(0.8)), lineWidth: 1)
        }
    }
}
