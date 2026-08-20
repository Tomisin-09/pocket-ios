import SwiftUI

/// The scrub strip on the take detail screen (ADR 0174) — a take's envelope as mirrored bars, a
/// playhead you can drag, and, in trim mode, two handles bounding the span to keep.
///
/// A **new** view rather than a reuse of `WaveformView`/`Minimap`: both of those are built around a
/// `Song` and take its loops, markers, beat grid and zoom viewport, none of which a take has. What
/// is reused is everything underneath them — `WaveformGesture` for point→fraction and the handle
/// maths, `WaveformAmplitude`/`WaveformBars` for the bar treatment — so a take's strip reads as the
/// same instrument as the song waveform without inheriting its screen.
///
/// The view emits **fractions** (0…1), never seconds and never points, so the caller owns the
/// mapping to a position in the file.
struct TakeScrubber: View {

    /// The take's envelope, or empty while it is still being extracted (drawn as a flat track).
    let samples: [Double]
    let playheadFraction: Double
    /// The keep-span while trimming, or `nil` when the strip is a plain scrubber. When set, the
    /// region outside it is dimmed and drags grab the nearest handle instead of the playhead.
    let trimSpan: (start: Double, end: Double)?
    /// Continuous scrub — fired while the finger moves, un-snapped.
    let onSeek: (Double) -> Void
    /// Drag release, so the caller can settle the position.
    let onSeekEnded: (Double) -> Void
    /// A trim handle was dragged to a fraction. Only fired in trim mode.
    let onMoveTrimHandle: (WaveformGesture.Handle, Double) -> Void

    /// Which handle the current drag grabbed, so a drag that starts on a handle keeps it even after
    /// the finger travels past the other one.
    @State private var grabbed: WaveformGesture.Handle?

    /// How close to a handle a touch must land to grab it. Generous, because the handles are thin
    /// and a take strip is short — the alternative is a player fighting the control.
    private static let handleTolerance = 0.06

    /// Bar drawing — the same target pitch and gap as the song waveform and minimap (ADR 0049/0055)
    /// so all three strips read as one style.
    private static let targetBarPitch: Double = 4
    private static let barGap: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            canvas
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = WaveformGesture.fraction(atX: value.location.x,
                                                                    width: geo.size.width)
                            handleChanged(at: fraction)
                        }
                        .onEnded { value in
                            let fraction = WaveformGesture.fraction(atX: value.location.x,
                                                                    width: geo.size.width)
                            handleEnded(at: fraction)
                        }
                )
        }
        .frame(height: 76)
        .accessibilityElement()
        .accessibilityLabel(trimSpan == nil ? "Take position" : "Trim range")
        .accessibilityValue("\(Int((playheadFraction * 100).rounded()))%")
        .accessibilityHint(trimSpan == nil ? "Adjust to move the playhead" : "Drag the handles to set what to keep")
        .accessibilityAdjustableAction { direction in
            let step = 0.05
            let target = direction == .increment ? playheadFraction + step : playheadFraction - step
            let clamped = min(max(target, 0), 1)
            onSeek(clamped)
            onSeekEnded(clamped)
        }
    }

    // MARK: - Gesture

    /// In trim mode a drag grabs the nearer handle (once, at touch-down) and moves it; otherwise it
    /// scrubs. Grabbing at touch-down rather than continuously is what lets a handle be dragged all
    /// the way across without the other one stealing it partway.
    private func handleChanged(at fraction: Double) {
        guard let span = trimSpan else {
            onSeek(fraction)
            return
        }
        if grabbed == nil {
            grabbed = WaveformGesture.nearestHandle(toFraction: fraction, start: span.start,
                                                    end: span.end, tolerance: Self.handleTolerance)
        }
        // A touch that lands nowhere near a handle still scrubs, so the playhead stays reachable
        // while a trim is being set up — you need to hear where the handles are.
        guard let grabbed else {
            onSeek(fraction)
            return
        }
        onMoveTrimHandle(grabbed, fraction)
    }

    private func handleEnded(at fraction: Double) {
        if trimSpan == nil || grabbed == nil { onSeekEnded(fraction) }
        grabbed = nil
    }

    // MARK: - Drawing

    private var canvas: some View {
        Canvas { context, size in
            drawBars(in: context, size: size)
            if let trimSpan {
                drawTrimChrome(in: context, size: size, span: trimSpan)
            }
            drawPlayhead(in: context, size: size)
        }
    }

    /// Mirrored rounded bars through the shared display gamma and grouping. Bars inside the keep-span
    /// (or the whole strip when not trimming) are drawn in the take's accent; bars outside it fall
    /// back to the played/dimmed tone, so what a trim would discard is visible as *quieter*, not as
    /// something hidden behind a wash.
    private func drawBars(in context: GraphicsContext, size: CGSize) {
        guard samples.count > 1 else {
            let base = CGRect(x: 0, y: size.height * 0.45, width: size.width, height: size.height * 0.1)
            context.fill(Path(roundedRect: base, cornerRadius: 2), with: .color(PocketColor.barPlayed))
            return
        }
        let midY = size.height / 2
        let maxHalf = size.height * 0.44
        let sourcePitch = size.width / CGFloat(samples.count)
        let group = WaveformBars.groupSize(sourcePitch: Double(sourcePitch), targetPitch: Self.targetBarPitch)
        let bars = WaveformBars.bucketedMean(samples, group: group)
        let pitch = sourcePitch * CGFloat(group)
        let barWidth = max(1.5, pitch - Self.barGap)
        let cap = barWidth / 2
        for (index, amp) in bars.enumerated() {
            let barX = CGFloat(index) * pitch
            guard barX > -barWidth, barX < size.width else { continue }
            let half = CGFloat(WaveformAmplitude.display(amp)) * maxHalf
            let rect = CGRect(x: barX, y: midY - half, width: barWidth, height: half * 2)
            let centre = Double((barX + barWidth / 2) / max(size.width, 1))
            context.fill(Path(roundedRect: rect, cornerRadius: cap, style: .continuous),
                         with: .color(barColor(atFraction: centre)))
        }
    }

    private func barColor(atFraction fraction: Double) -> Color {
        guard let trimSpan else { return PocketColor.practice }
        let kept = fraction >= trimSpan.start && fraction <= trimSpan.end
        return kept ? PocketColor.practice : PocketColor.barPlayed
    }

    /// The trim handles: a vertical rule at each edge with a grab bar, drawn on top of the bars.
    private func drawTrimChrome(in context: GraphicsContext, size: CGSize, span: (start: Double, end: Double)) {
        for edge in [span.start, span.end] {
            let edgeX = CGFloat(edge) * size.width
            let rule = CGRect(x: edgeX - 1.5, y: 0, width: 3, height: size.height)
            context.fill(Path(roundedRect: rule, cornerRadius: 1.5),
                         with: .color(PocketColor.fine))
            let grip = CGRect(x: edgeX - 5, y: size.height / 2 - 12, width: 10, height: 24)
            context.fill(Path(roundedRect: grip, cornerRadius: 5, style: .continuous),
                         with: .color(PocketColor.fine))
        }
    }

    private func drawPlayhead(in context: GraphicsContext, size: CGSize) {
        let headX = CGFloat(min(max(playheadFraction, 0), 1)) * size.width
        var line = Path()
        line.move(to: CGPoint(x: headX, y: 0))
        line.addLine(to: CGPoint(x: headX, y: size.height))
        context.stroke(line, with: .color(PocketColor.textPrimary), lineWidth: 1.5)
    }
}

/// The take strip and its timecodes, and **the only thing on the detail screen that reads the
/// playback position** (ADR 0153: a per-tick dependency lives in a leaf that draws a moving
/// playhead, never in a body that also carries menus, sheets and derived state). Everything
/// expensive — the envelope, the take's length — arrives as a parameter, already computed by the
/// screen's body, which runs only on real change.
struct PlayheadTakeScrubber: View {
    let player: RecordingPlayer
    let fileName: String
    let duration: TimeInterval
    let samples: [Double]
    let trimSpan: (start: Double, end: Double)?
    let onSeek: (Double) -> Void
    let onMoveTrimHandle: (WaveformGesture.Handle, Double) -> Void

    var body: some View {
        VStack(spacing: 6) {
            TakeScrubber(samples: samples,
                         playheadFraction: playheadFraction,
                         trimSpan: trimSpan,
                         onSeek: onSeek,
                         onSeekEnded: onSeek,
                         onMoveTrimHandle: onMoveTrimHandle)
            HStack {
                Text(timecode(position))
                Spacer(minLength: 8)
                Text(timecode(duration))
            }
            .font(.pocketMono(.caption))
            .foregroundStyle(PocketColor.textSecondary)
        }
    }

    /// The position within *this* take — zero when some other take is loaded, so the strip never
    /// shows a playhead borrowed from a different recording.
    private var position: TimeInterval {
        player.isLoaded(fileName) ? player.position : 0
    }

    private var playheadFraction: Double {
        TakeTrim.fraction(of: position, duration: duration)
    }
}
