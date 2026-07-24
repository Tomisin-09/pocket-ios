import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Light haptic for gesture confirmations — no-op where UIKit is unavailable.
///
/// Reuses a cached, pre-warmed `UIImpactFeedbackGenerator` per style. Allocating
/// a fresh generator and firing immediately leaves the Taptic Engine cold, which
/// adds tens of milliseconds of perceived lag on the first buzz — felt most on
/// rapid feedback like tap-tempo. Keeping the generator alive and re-`prepare()`ing
/// after each impact keeps the engine warm so the next buzz is near-instant.
@MainActor func haptic(_ style: HapticStyle) {
    guard AppSettings.hapticsEnabled else { return }   // Settings V1 (ADR 0050)
    HapticEngine.shared.fire(style)
}

/// Warm the Taptic Engine ahead of imminent, latency-sensitive feedback (e.g. on
/// touch-down before a tap-tempo tap commits). Safe to call repeatedly.
@MainActor func prepareHaptics(_ style: HapticStyle = .light) {
    HapticEngine.shared.prepare(style)
}

enum HapticStyle: Hashable {
    /// Impact buzzes for gesture confirmations.
    case light, medium
    /// The system **success** notification pattern (da-dum) — used when the tuner confirms a string has
    /// held in tune (ADR 0115), distinct from the plain impacts so "you nailed it" feels like an event.
    case success
}

/// Holds long-lived feedback generators so the Taptic Engine stays warm between
/// buzzes instead of being re-allocated cold on every gesture.
@MainActor final class HapticEngine {
    static let shared = HapticEngine()
    private init() {}

    #if canImport(UIKit)
    private var impactGenerators: [HapticStyle: UIImpactFeedbackGenerator] = [:]
    private lazy var notificationGenerator: UINotificationFeedbackGenerator = {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        return generator
    }()

    private func impactStyle(_ style: HapticStyle) -> UIImpactFeedbackGenerator.FeedbackStyle {
        style == .light ? .light : .medium
    }

    private func impactGenerator(for style: HapticStyle) -> UIImpactFeedbackGenerator {
        if let existing = impactGenerators[style] { return existing }
        let made = UIImpactFeedbackGenerator(style: impactStyle(style))
        made.prepare()
        impactGenerators[style] = made
        return made
    }

    func prepare(_ style: HapticStyle) {
        if style == .success { notificationGenerator.prepare() } else { impactGenerator(for: style).prepare() }
    }

    func fire(_ style: HapticStyle) {
        if style == .success {
            notificationGenerator.notificationOccurred(.success)
            notificationGenerator.prepare() // keep warm
            return
        }
        let generator = impactGenerator(for: style)
        generator.impactOccurred()
        generator.prepare() // keep warm for the next buzz
    }
    #else
    func prepare(_ style: HapticStyle) {}
    func fire(_ style: HapticStyle) {}
    #endif
}
