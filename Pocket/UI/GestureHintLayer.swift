import SwiftUI

// MARK: - Hold tips (ADR 0244)
//
// Each control a tag can point at reports where it is (`.gestureHintTarget`). One layer over the
// whole screen (`.gestureHintLayer`) reads those positions, asks `GestureHintPolicy` which tag to
// show, and draws it: the walkthrough's ring round the control, and a tag beside it with a ✕.
//
// **Drawn by the layer, not by the control.** A tag drawn as an overlay on a loop row is clipped by
// the scroll view it sits in and covered by the row below it; drawn over the whole screen it is
// neither. The price is the scroll view's own edges, which the layer cannot see — so the scroll view
// reports them too (`.gestureHintViewport`), and a row only counts as on screen inside them.

/// What this opening of the app has already done (D3, D5): one tag an opening across every time the
/// song player opens, and none in the opening that ran the first-song walkthrough.
///
/// An opening is a launch, or a return after `GestureHintPolicy.openingGap` or more in the background;
/// `PocketApp` reports each change of scene phase. **Observable**, so a new opening that begins with the
/// song player on screen redraws its layer, and Settings ▸ Developer can show it.
@MainActor
@Observable
final class GestureHintOpening {
    static let current = GestureHintOpening()

    /// Set by the song player when it takes the armed walkthrough.
    var walkthroughSeen = false
    /// The tag this opening has shown. It stays the only candidate until it is used or closed.
    var shown: GestureHint?
    /// When the app went to the background, while it is there.
    @ObservationIgnored private var awaySince: Date?

    /// Only the background counts as away. `.inactive` is Control Centre, a call's banner or the app
    /// switcher: a glance, not a break.
    func sceneChanged(to phase: ScenePhase, at now: Date = .now) {
        switch phase {
        case .background:
            if awaySince == nil { awaySince = now }
        case .active:
            if GestureHintPolicy.isNewOpening(awaySince: awaySince, now: now) { begin() }
            awaySince = nil
        default:
            break
        }
    }

    /// What coming back after a break does. Settings ▸ Developer calls it too, so a test on a device
    /// takes this path rather than one of its own.
    func begin() {
        walkthroughSeen = false
        shown = nil
    }

    /// The walkthrough is armed, and the next song opened runs it (D3). Outstanding only where it can
    /// run: under `-uiTesting` without `-walkthrough` it never will, and a ledger a past run left armed
    /// must not hold the tags back for ever. The layer and Settings ▸ Developer both read this.
    static var walkthroughOutstanding: Bool {
        UITestRuntime.walkthroughIsOpen && AppSettings.songWalkthroughLedger() == .armed
    }
}

extension View {
    /// Report this control to the hold-tips layer as where `hint` points, while `isEligible`. Put it on
    /// the part that takes the hold, so the ring goes round that and not round its neighbours.
    /// `scrolls` marks a control inside the `.gestureHintViewport` scroll view.
    func gestureHintTarget(_ hint: GestureHint, when isEligible: Bool = true, scrolls: Bool = false) -> some View {
        modifier(GestureHintTargetModifier(hint: hint, isEligible: isEligible, scrolls: scrolls))
    }

    /// Mark the scroll view whose rows report `scrolls: true`: the part of them that is visible.
    func gestureHintViewport() -> some View {
        transformAnchorPreference(key: GestureHintGeometryKey.self, value: .bounds) { geometry, anchor in
            geometry.viewport = anchor
        }
    }

    /// The layer that draws the tags, over everything this modifies. `isIdle` is the screen's own
    /// condition — nothing loading, nothing playing, nothing mid-edit — on top of the policy's.
    ///
    /// **A closure, read in the layer's own body**, not a `Bool` read in the screen's. The song player's
    /// condition reads state that changes on every frame of a drag (the 1 being placed), and a root
    /// body that read it would rebuild the whole screen at display rate — ADR 0153's trap.
    func gestureHintLayer(isIdle: @escaping () -> Bool) -> some View {
        modifier(GestureHintLayer(isIdle: isIdle))
    }
}

// MARK: - Reporting positions

struct GestureHintGeometry {
    struct Target {
        var anchor: Anchor<CGRect>
        var scrolls: Bool
    }

    var targets: [GestureHint: Target] = [:]
    var viewport: Anchor<CGRect>?
}

struct GestureHintGeometryKey: PreferenceKey {
    static var defaultValue: GestureHintGeometry { GestureHintGeometry() }

    /// The first report of a hint wins: of several loop rows, the top one gets the tag.
    static func reduce(value: inout GestureHintGeometry, nextValue: () -> GestureHintGeometry) {
        let next = nextValue()
        value.targets.merge(next.targets) { first, _ in first }
        value.viewport = value.viewport ?? next.viewport
    }
}

private struct GestureHintCandidatesKey: EnvironmentKey {
    static let defaultValue: Set<GestureHint> = []
}

extension EnvironmentValues {
    /// The tags still in play, set by the layer. A control reports its position only while its own
    /// is among them, so once every tag is retired the screen reports nothing at all.
    var gestureHintCandidates: Set<GestureHint> {
        get { self[GestureHintCandidatesKey.self] }
        set { self[GestureHintCandidatesKey.self] = newValue }
    }
}

private struct GestureHintTargetModifier: ViewModifier {
    let hint: GestureHint
    let isEligible: Bool
    let scrolls: Bool
    @Environment(\.gestureHintCandidates) private var candidates

    func body(content: Content) -> some View {
        let reports = isEligible && candidates.contains(hint)
        content.transformAnchorPreference(key: GestureHintGeometryKey.self, value: .bounds) { geometry, anchor in
            guard reports, geometry.targets[hint] == nil else { return }
            geometry.targets[hint] = .init(anchor: anchor, scrolls: scrolls)
        }
    }
}

// MARK: - The layer

private struct GestureHintLayer: ViewModifier {
    let isIdle: () -> Bool
    @AppStorage(AppSettings.Key.gestureHints) private var enabled = AppSettings.gestureHintsDefault
    @AppStorage(AppSettings.Key.gestureHintsRetired) private var retiredStored = ""
    /// The tag this layer has announced, so VoiceOver hears it once a visit and not after every pause.
    @State private var announced: GestureHint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var candidates: Set<GestureHint> {
        guard UITestRuntime.gestureHintsAreOpen, isIdle() else { return [] }
        return GestureHintPolicy.candidates(
            enabled: enabled,
            retired: GestureHintPolicy.retired(retiredStored),
            walkthroughOutstanding: GestureHintOpening.walkthroughOutstanding,
            walkthroughSeenThisOpening: GestureHintOpening.current.walkthroughSeen,
            shownThisOpening: GestureHintOpening.current.shown)
    }

    func body(content: Content) -> some View {
        let candidates = candidates
        content
            .environment(\.gestureHintCandidates, candidates)
            .overlayPreferenceValue(GestureHintGeometryKey.self) { geometry in
                GeometryReader { proxy in
                    let bounds = CGRect(origin: .zero, size: proxy.size)
                    let chosen = GestureHintPolicy.next(onScreen: onScreen(geometry, in: proxy, bounds: bounds),
                                                        candidates: candidates)
                    ZStack(alignment: .topLeading) {
                        if let chosen, let target = geometry.targets[chosen] {
                            GestureHintTag(hint: chosen, target: proxy[target.anchor], bounds: bounds) {
                                AppSettings.retireGestureHint(chosen)
                            }
                            // A new opening can swap one tag for another with nothing between; keyed on
                            // the tag, the new one appears, and is latched, in its own right.
                            .id(chosen)
                            .transition(.opacity)
                            .onAppear { latch(chosen) }
                        }
                    }
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: chosen)
                }
            }
    }

    /// The tag on screen is this opening's one, and VoiceOver hears it once a visit.
    private func latch(_ chosen: GestureHint) {
        if announced != chosen { AccessibilityNotification.Announcement(chosen.text).post() }
        announced = chosen
        let opening = GestureHintOpening.current
        if opening.shown != chosen { opening.shown = chosen }
    }

    /// The reported controls wholly inside the screen and, for a row, inside the visible part of its
    /// scroll view. A tag pointing at something half off the edge points at nothing the player can hold.
    private func onScreen(_ geometry: GestureHintGeometry, in proxy: GeometryProxy,
                          bounds: CGRect) -> Set<GestureHint> {
        let viewport = geometry.viewport.map { proxy[$0] }
        return Set(geometry.targets.compactMap { hint, target -> GestureHint? in
            let rect = proxy[target.anchor].insetBy(dx: 1, dy: 1)
            guard bounds.contains(rect) else { return nil }
            if target.scrolls {
                guard let viewport, viewport.contains(rect) else { return nil }
            }
            return hint
        })
    }
}

// MARK: - The tag

/// Where a tag sits beside its control. Pure, so the edge cases (a control at the very top, one hard
/// against a side) are tested without drawing anything.
struct GestureHintPlacement: Equatable {
    /// Above the control, or below it.
    var above: Bool
    /// The tag's leading edge, in the layer's coordinates.
    var leading: CGFloat
    /// The caret's centre, from the tag's leading edge.
    var caretX: CGFloat

    static let margin: CGFloat = 16
    static let gap: CGFloat = 10
    static let maxWidth: CGFloat = 300
    /// About a two-line tag and its caret. Above is preferred — the hand that holds comes from below
    /// and would cover a tag there — whenever this much room is free.
    static let roomAbove: CGFloat = 96
    static let caretInset: CGFloat = 16

    static func width(in bounds: CGRect) -> CGFloat {
        max(0, min(maxWidth, bounds.width - 2 * margin))
    }

    static func make(target: CGRect, bounds: CGRect, width: CGFloat) -> GestureHintPlacement {
        let spaceAbove = target.minY - bounds.minY
        let spaceBelow = bounds.maxY - target.maxY
        let above = spaceAbove >= roomAbove || spaceAbove > spaceBelow
        let lowest = bounds.minX + margin
        let highest = max(lowest, bounds.maxX - margin - width)
        let leading = min(max(target.midX - width / 2, lowest), highest)
        let caretX = min(max(target.midX - leading, caretInset), max(caretInset, width - caretInset))
        return GestureHintPlacement(above: above, leading: leading, caretX: caretX)
    }
}

/// The ring round the control and the tag beside it. Only the tag takes touches: the ring is
/// `HintRing`, which is never hit-tested, so the hold it asks for still lands on the control.
private struct GestureHintTag: View {
    let hint: GestureHint
    let target: CGRect
    let bounds: CGRect
    let onClose: () -> Void

    var body: some View {
        let width = GestureHintPlacement.width(in: bounds)
        let placement = GestureHintPlacement.make(target: target, bounds: bounds, width: width)
        let gap = GestureHintPlacement.gap
        ZStack(alignment: .topLeading) {
            ring
                .frame(width: target.width + 8, height: target.height + 8)
                .position(x: target.midX, y: target.midY)
            tag(width: width, placement: placement)
                .frame(width: bounds.width,
                       height: max(0, placement.above ? target.minY - gap : bounds.height - target.maxY - gap),
                       alignment: placement.above ? .bottomLeading : .topLeading)
                .offset(y: placement.above ? 0 : target.maxY + gap)
        }
        .frame(width: bounds.width, height: bounds.height, alignment: .topLeading)
    }

    @ViewBuilder private var ring: some View {
        if hint.ringIsCircle {
            HintRing(color: PocketColor.waveformAccent)
        } else {
            HintRing(color: PocketColor.waveformAccent,
                     shape: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func tag(width: CGFloat, placement: GestureHintPlacement) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Text(hint.text)
                .font(.futura(.footnote, weight: .medium))
                .foregroundStyle(PocketColor.background)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.futura(size: 11, weight: .semibold))
                    .foregroundStyle(PocketColor.background.opacity(0.85))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close this tip")
            .accessibilityIdentifier("gestureHint.close")
        }
        .padding(.leading, 12)
        .padding(.trailing, 2)
        .padding(.vertical, 4)
        .frame(width: width)
        // The CTA fill, not the waveform's own teal: it is the one the background ink is measured
        // against (≥ 4.5 : 1 in both appearances, ADR 0062), and it is what the walkthrough's
        // *Show me* already uses on this screen.
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(PocketColor.practiceCTA))
        .overlay(alignment: placement.above ? .bottomLeading : .topLeading) {
            GestureHintCaret(pointsDown: placement.above)
                .fill(PocketColor.practiceCTA)
                .frame(width: 14, height: 7)
                .offset(x: placement.caretX - 7, y: placement.above ? 7 : -7)
                .accessibilityHidden(true)
        }
        .shadow(color: .black.opacity(0.22), radius: 8, y: 2)
        .accessibilityElement(children: .contain)
        .padding(.leading, placement.leading)
    }
}

/// The small triangle that joins a tag to what it points at.
private struct GestureHintCaret: Shape {
    let pointsDown: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointsDown {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        }
        path.closeSubpath()
        return path
    }
}
