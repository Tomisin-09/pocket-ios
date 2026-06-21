import SwiftUI

/// Suppresses the navigation stack's interactive pop (the iOS left-edge
/// swipe-back) while `disabled` is true, then restores it (pocket-040, ADR 0030).
///
/// Why: a playhead scrub that starts near the screen's left edge competes with the
/// system edge-pan, which would yank the practice screen back to the library
/// mid-adjust. The waveform's drag fires on touch-down (`minimumDistance: 0`), so
/// flipping `disabled` true then cancels any edge-pan already tracking — the
/// scrub wins. Restored on release so the back-swipe works normally otherwise.
struct SwipeBackGuard: UIViewControllerRepresentable {
    let disabled: Bool

    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.disabled = disabled
        controller.apply()
    }

    final class Controller: UIViewController {
        var disabled = false

        /// Toggle the recogniser. Setting `isEnabled = false` on an in-progress
        /// gesture cancels it, so a scrub that began at the edge stops the pop.
        func apply() {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = !disabled
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            apply()
        }

        // Leave the recogniser enabled when this view goes away, so the guard can't
        // strand the back-swipe disabled after the practice screen is dismissed.
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}
