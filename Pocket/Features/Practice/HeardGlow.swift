import SwiftUI

/// The glow on the neck while the strip plays the loop or a phrase (ADR 0227 D2), moving **the way each note
/// was played** (ADR 0234 D5, `HaloMotion`): a picked note pops, a bend glides to where it lands, vibrato
/// shakes, a hammer-on or pull-off lights where it started and snaps across, a slide travels along the
/// string. It sits under the dots, in the board's coordinates (`FretNeckBoard.beneath`), and stays lit while
/// the note is heard, fading as the next takes over. With Reduce Motion it only fades in, where the note is.
/// The neck never scrolls to follow it, so the board can't move under a finger that's naming.
struct HeardGlows: View {
    /// One per note of the chip being heard (a shape glows on every string).
    let motions: [HaloMotion]
    /// Changes with each note heard, so each one's glow plays from its start.
    let token: Int?
    let headroom: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let token {
                Group {
                    ForEach(motions.indices, id: \.self) { index in
                        HeardGlow(motion: motions[index], headroom: headroom, reduceMotion: reduceMotion)
                    }
                }
                .id(token)
                .transition(.asymmetric(insertion: .identity, removal: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeIn(duration: 0.25), value: token)
        .accessibilityHidden(true)
    }
}

/// One note's glow, played once when it appears. The trigger flips on appear because the other form of
/// `keyframeAnimator` with `repeating: false` doesn't play once: it holds the first frame.
private struct HeardGlow: View {
    let motion: HaloMotion
    let headroom: CGFloat
    let reduceMotion: Bool
    @State private var started = false
    @Environment(\.neckAccent) private var accent

    struct Frame {
        var across: CGFloat
        var down: CGFloat
        var scale: CGFloat
        var opacity: Double
    }

    var body: some View {
        Circle()
            .fill(accent.opacity(0.42))
            .frame(width: 36, height: 36)
            .keyframeAnimator(initialValue: first, trigger: started) { content, frame in
                content
                    .scaleEffect(frame.scale)
                    .opacity(frame.opacity)
                    .position(x: frame.across, y: frame.down)
            } keyframes: { _ in
                KeyframeTrack(\.across) { xFrames }
                KeyframeTrack(\.down) { MoveKeyframe(point(motion.end).y) }
                KeyframeTrack(\.scale) { scaleFrames }
                KeyframeTrack(\.opacity) { opacityFrames }
            }
            .onAppear { started = true }
    }

    private func point(_ spot: NeckSpot) -> CGPoint {
        NeckGeometry.center(string: spot.string, fret: spot.fret, headroom: headroom)
    }

    /// Where it starts: the fret it came from, off the fret for a slide from nowhere, else the note.
    private var startX: CGFloat {
        guard !reduceMotion else { return point(motion.end).x }
        switch motion {
        case .bend(let from, _), .legato(let from, _), .slide(let from, _): return point(from).x
        case .slideIn(let to, let fromBelow):
            return point(to).x + (fromBelow ? -1.4 : 1.4) * NeckGeometry.pitch
        case .pop(let spot), .vibrato(let spot): return point(spot).x
        }
    }

    private var first: Frame {
        let reachedFromAFret: Bool
        switch motion {
        case .legato, .slide: reachedFromAFret = true
        default: reachedFromAFret = false
        }
        return Frame(across: startX, down: point(motion.end).y, scale: reduceMotion ? 1 : 0.6,
                     opacity: reachedFromAFret && !reduceMotion ? 0.85 : 0)
    }

    @KeyframeTrackContentBuilder<CGFloat> private var xFrames: some KeyframeTrackContent<CGFloat> {
        let end = point(motion.end).x
        switch (reduceMotion, motion) {
        case (true, _), (_, .pop):
            MoveKeyframe(end)
        case (_, .bend):
            // Lit where it was fretted, then pushed up to where it lands.
            LinearKeyframe(startX, duration: 0.16)
            CubicKeyframe(end, duration: 0.4)
        case (_, .vibrato):
            // Side to side along the string, as a finger rocks it, then still.
            LinearKeyframe(end, duration: 0.12)
            CubicKeyframe(end - 3.5, duration: 0.09)
            CubicKeyframe(end + 3.5, duration: 0.09)
            CubicKeyframe(end - 3.5, duration: 0.09)
            CubicKeyframe(end + 3.5, duration: 0.09)
            CubicKeyframe(end - 2, duration: 0.09)
            CubicKeyframe(end, duration: 0.09)
        case (_, .legato):
            // The fret it came from flashes, then it snaps across: no travel, since the string isn't slid.
            LinearKeyframe(startX, duration: 0.14)
            MoveKeyframe(end)
        case (_, .slide), (_, .slideIn):
            CubicKeyframe(end, duration: 0.34)
        }
    }

    @KeyframeTrackContentBuilder<CGFloat> private var scaleFrames: some KeyframeTrackContent<CGFloat> {
        switch (reduceMotion, motion) {
        case (true, _):
            MoveKeyframe(1)
        case (_, .legato(let from, let to)):
            LinearKeyframe(0.85, duration: 0.14)
            // A hammer-on lands hard; a pull-off flicks off, smaller, then settles.
            MoveKeyframe(to.fret > from.fret ? 1.3 : 0.8)
            CubicKeyframe(1, duration: 0.18)
        case (_, .slide), (_, .slideIn):
            CubicKeyframe(1, duration: 0.34)
        default:
            CubicKeyframe(1.12, duration: 0.12)
            CubicKeyframe(1, duration: 0.14)
        }
    }

    @KeyframeTrackContentBuilder<Double> private var opacityFrames: some KeyframeTrackContent<Double> {
        switch (reduceMotion, motion) {
        case (true, _):
            LinearKeyframe(1, duration: 0.16)
        case (_, .legato), (_, .slide):
            LinearKeyframe(1, duration: 0.14)
        default:
            LinearKeyframe(1, duration: 0.12)
        }
    }
}
