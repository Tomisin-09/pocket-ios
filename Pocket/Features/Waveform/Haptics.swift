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
    HapticEngine.shared.fire(style)
}

/// Warm the Taptic Engine ahead of imminent, latency-sensitive feedback (e.g. on
/// touch-down before a tap-tempo tap commits). Safe to call repeatedly.
@MainActor func prepareHaptics(_ style: HapticStyle = .light) {
    HapticEngine.shared.prepare(style)
}

enum HapticStyle: Hashable {
    case light, medium
    #if canImport(UIKit)
    var uiStyle: UIImpactFeedbackGenerator.FeedbackStyle { self == .light ? .light : .medium }
    #endif
}

/// Holds long-lived feedback generators so the Taptic Engine stays warm between
/// buzzes instead of being re-allocated cold on every gesture.
@MainActor final class HapticEngine {
    static let shared = HapticEngine()
    private init() {}

    #if canImport(UIKit)
    private var generators: [HapticStyle: UIImpactFeedbackGenerator] = [:]

    private func generator(for style: HapticStyle) -> UIImpactFeedbackGenerator {
        if let existing = generators[style] { return existing }
        let made = UIImpactFeedbackGenerator(style: style.uiStyle)
        made.prepare()
        generators[style] = made
        return made
    }

    func prepare(_ style: HapticStyle) {
        generator(for: style).prepare()
    }

    func fire(_ style: HapticStyle) {
        let generator = generator(for: style)
        generator.impactOccurred()
        generator.prepare() // keep warm for the next buzz
    }
    #else
    func prepare(_ style: HapticStyle) {}
    func fire(_ style: HapticStyle) {}
    #endif
}
