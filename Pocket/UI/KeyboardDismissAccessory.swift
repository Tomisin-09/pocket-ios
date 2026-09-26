import SwiftUI
import UIKit

/// **The app's one way off the keyboard** — a checkmark floating just above it, on every text surface,
/// installed once at launch (`AppDelegate`) the way `NavigationBarStyle` is.
///
/// It replaces `keyboardDoneButton()` and two hand-rolled copies of it — a
/// `ToolbarItemGroup(placement: .keyboard)` attached at fifteen call sites, one at a time. That
/// accessory stopped drawing on a device on iOS 26.6 — on every screen at once, while the iOS 26.5
/// simulator still drew it — and SwiftUI's keyboard toolbar has failed like this before: in sheets on
/// iOS 17, on real devices only on iOS 16. A number pad has no Return key,
/// so where it fails there is no way off the keyboard at all. This reads nothing but the keyboard's
/// frame notifications and draws in a window of its own, so it depends on none of that bridging.
///
/// Owning it globally fixed two more things:
/// - **One button, always.** The modifier stacked: the metronome with its automator on drew four
///   checkmarks side by side, one for the screen and one for each number field.
/// - **No screen can forget it.** ADR 0167 found a Link field that shipped with no way off the keyboard
///   because nobody attached the modifier. There is nothing to attach now.
///
/// Skipped for a **search field** (its Search key and Cancel already end it) and for a field inside an
/// **alert** (the alert's own buttons do, and a checkmark floating beside a dimmed alert would be the
/// one undimmed thing on screen).
///
/// The window is the size of the button and never becomes key, so it takes no touches but its own,
/// never owns the status bar, and leaves the focused field first responder — which is what lets
/// `sendAction(to: nil)` reach it.
@MainActor
enum KeyboardDismissAccessory {
    private static var window: UIWindow?
    private static var observers: [NSObjectProtocol] = []
    /// The keyboard's last end frame, in screen coordinates — `nil` when it is hidden. Kept so that
    /// focus moving between two fields, which need not move the keyboard, can still be re-judged.
    private static var keyboardFrame: CGRect?

    static func install() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification,
                                            object: nil, queue: .main) { note in
            let end = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            MainActor.assumeIsolated { keyboardMoved(to: end) }
        })
        observers.append(center.addObserver(forName: UIResponder.keyboardWillHideNotification,
                                            object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { keyboardMoved(to: nil) }
        })
        for name in [UITextField.textDidBeginEditingNotification, UITextView.textDidBeginEditingNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { scheduleRefresh() }
            })
        }
    }

    /// Whether the input that has focus should get the checkmark. Split out and not private so the
    /// exclusions can be tested against real UIKit objects.
    static func wantsCheckmark(for responder: UIResponder?) -> Bool {
        // Only a text input: a keyboard can also belong to an out-of-process view (the file importer's
        // search), and a checkmark over someone else's screen would reach nothing.
        guard let responder, responder is UITextInput else { return false }
        if responder is UISearchTextField { return false }
        var next: UIResponder? = responder
        while let current = next {
            if current is UIAlertController { return false }
            next = current.next
        }
        return true
    }

    private static func keyboardMoved(to end: CGRect?) {
        keyboardFrame = end
        scheduleRefresh()
    }

    /// Re-judged on the next turn of the main queue rather than inside the notification: the keyboard
    /// notifications are posted while focus is still moving, and the answer depends on who has it.
    private static func scheduleRefresh() {
        Task { @MainActor in refresh() }
    }

    private static func refresh() {
        guard let keyboardFrame, let scene = activeScene(),
              wantsCheckmark(for: FirstResponder.current) else { return hide() }
        let space = scene.coordinateSpace
        let keyboard = space.convert(keyboardFrame, from: scene.screen.coordinateSpace)
        guard let frame = KeyboardAccessoryPlacement.frame(
            keyboard: keyboard, in: space.bounds,
            trailingSafeInset: scene.keyWindow?.safeAreaInsets.right ?? 0) else { return hide() }
        show(at: frame, in: scene)
    }

    private static func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    private static func show(at frame: CGRect, in scene: UIWindowScene) {
        let window = window ?? makeWindow(in: scene)
        window.frame = frame
        guard window.isHidden else { return }
        window.alpha = 0
        window.isHidden = false
        UIView.animate(withDuration: 0.2) { window.alpha = 1 }
    }

    private static func hide() {
        guard let window, !window.isHidden else { return }
        UIView.animate(withDuration: 0.15, animations: { window.alpha = 0 }, completion: { _ in
            // A show that landed during the fade set the alpha back to 1; leave that one standing.
            if window.alpha == 0 { window.isHidden = true }
        })
    }

    private static func makeWindow(in scene: UIWindowScene) -> UIWindow {
        let window = UIWindow(windowScene: scene)
        // Above the app's window, which holds every sheet and cover too. It never overlaps the keyboard,
        // so its order relative to the keyboard's own windows does not matter.
        window.windowLevel = .normal + 1
        window.backgroundColor = .clear
        let host = UIHostingController(rootView: KeyboardDismissButton())
        host.view.backgroundColor = .clear
        // The window is button-sized: a safe area inside it would only push the button off-centre.
        host.safeAreaRegions = []
        window.rootViewController = host
        self.window = window
        return window
    }
}

/// The checkmark itself. Glass on iOS 26, to sit with the keyboard the way the system's own floating
/// button does; a material disc before it. The glass modifier exists only in the iOS 26 SDK, so
/// `#if compiler` keeps it out of CI's Xcode 16 build, where a runtime `#available` could not.
private struct KeyboardDismissButton: View {
    var body: some View {
        Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        } label: {
            Image(systemName: "checkmark")
                .font(.futura(.body, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(width: KeyboardAccessoryPlacement.side, height: KeyboardAccessoryPlacement.side)
                .modifier(KeyboardButtonSurface())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss keyboard")
    }
}

private struct KeyboardButtonSurface: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .circle)
        } else {
            materialDisc(content)
        }
        #else
        materialDisc(content)
        #endif
    }

    private func materialDisc(_ content: Content) -> some View {
        content
            .background(.regularMaterial, in: Circle())
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }
}

/// Finds whatever has focus, anywhere: an action sent to `nil` is delivered to the first responder,
/// and the first responder answers by naming itself.
@MainActor
private enum FirstResponder {
    fileprivate static weak var found: UIResponder?

    static var current: UIResponder? {
        found = nil
        UIApplication.shared.sendAction(#selector(UIResponder.pocketReportFirstResponder(_:)),
                                        to: nil, from: nil, for: nil)
        return found
    }
}

private extension UIResponder {
    @objc func pocketReportFirstResponder(_ sender: Any?) {
        FirstResponder.found = self
    }
}
