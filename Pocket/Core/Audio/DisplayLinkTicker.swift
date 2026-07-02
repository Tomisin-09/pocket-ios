import QuartzCore

/// Fires a callback once per display refresh (vsync-aligned, 60/120 Hz), used to
/// advance the playhead smoothly instead of a fixed-interval `Timer` that beats
/// against the display and steps below its refresh rate (ADR 0054).
///
/// `CADisplayLink` retains its target, so the `@objc` hop goes through a plain
/// `NSObject` proxy and the ticker `invalidate()`s on `stop`/`deinit` to break the
/// cycle. The link is added to the main run loop, so `tick` runs on the main
/// thread — the owner does its main-actor work via `MainActor.assumeIsolated`.
final class DisplayLinkTicker {
    private final class Proxy: NSObject {
        var onTick: (() -> Void)?
        @objc func tick() { onTick?() }
    }

    private let proxy = Proxy()
    private var link: CADisplayLink?

    /// `onTick` fires on the main thread, once per frame, while running.
    init(onTick: @escaping () -> Void) {
        proxy.onTick = onTick
    }

    /// Start ticking. No-op if already running.
    func start() {
        guard link == nil else { return }
        let displayLink = CADisplayLink(target: proxy, selector: #selector(Proxy.tick))
        displayLink.add(to: .main, forMode: .common)
        link = displayLink
    }

    /// Stop ticking and release the link (breaking the target retain cycle).
    func stop() {
        link?.invalidate()
        link = nil
    }

    deinit { link?.invalidate() }
}
