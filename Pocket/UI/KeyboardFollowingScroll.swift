import SwiftUI

/// Keeping a **growing text field above the keyboard** — the shared half of the fix for the note
/// fields that vanish under it (v2 close-out N5).
///
/// iOS already scrolls a *newly focused* field into view inside a `Form`/`List`. What it does not do
/// is follow that field as it **grows**: every note field in the app is `axis: .vertical` with a
/// `lineLimit` range, so the first line break pushes its bottom edge under the keyboard and the
/// caret goes with it. The trigger here is therefore a height *increase while focused*, not a
/// keystroke — scrolling on every character would be worse than the bug it fixes.
///
/// Two pieces because the fields are not all in their hosts. `JournalNoteComposer` and
/// `FreeformInstructionsSection` are reusable `Section`s with two hosts each, so a field cannot reach
/// its own scroll container: `KeyboardFollowingScroll` publishes the `ScrollViewProxy` into the
/// environment and `scrollsIntoViewWhenFocused` reads it back out, wherever it happens to be nested.
/// A host that forgets the wrapper degrades to today's behaviour rather than breaking — the proxy is
/// `nil` and the modifier does nothing.

/// The growth rule, kept off the `View` so it stays free of main-actor isolation and a test can read
/// it (the same reason `TempoMath.percentRange` doesn't live on a screen).
enum FocusScroll {
    /// Ignore sub-point jitter — a `TextField`'s reported height wobbles by fractions as it lays out,
    /// and a scroll per wobble would read as the view shivering. A real line break is ~20 pt.
    static let growthThreshold: CGFloat = 1

    /// Whether a height change is worth scrolling for: the field must be **focused** (an unfocused
    /// field growing is someone else's layout pass, not the caret moving) and must have grown, not
    /// shrunk — collapsing back after a deleted line already leaves the caret visible.
    static func shouldScroll(from oldHeight: CGFloat, to newHeight: CGFloat, focused: Bool) -> Bool {
        focused && newHeight > oldHeight + growthThreshold
    }
}

private struct FocusScrollProxyKey: EnvironmentKey {
    /// Computed, not stored: `ScrollViewProxy` isn't `Sendable`, and a *stored* static of a
    /// non-`Sendable` type is shared mutable state under Swift 6 strict concurrency (CI's toolchain
    /// enforces this before local Xcode does). Returning `nil` each time stores nothing.
    static var defaultValue: ScrollViewProxy? { nil }
}

extension EnvironmentValues {
    /// The enclosing `KeyboardFollowingScroll`'s proxy, or `nil` when there isn't one.
    var focusScrollProxy: ScrollViewProxy? {
        get { self[FocusScrollProxyKey.self] }
        set { self[FocusScrollProxyKey.self] = newValue }
    }
}

/// Wraps a scroll container (`Form`, `List`, `ScrollView`) so the fields inside it can ask to be
/// scrolled to. Goes **outside** the container, as `ScrollViewReader` requires.
///
/// The environment is applied to `content`, so the container and every row in it can read the proxy —
/// this view never reads it itself, which is the direction that works (a `.environment` applied in a
/// `body` is invisible to the view that applied it, only to its descendants).
struct KeyboardFollowingScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollViewReader { proxy in
            content.environment(\.focusScrollProxy, proxy)
        }
    }
}

extension View {
    /// Bind a text field to `focused` and keep it in view as it grows — scrolls to centre on gaining
    /// focus, and again whenever the field gets taller while it still has the caret.
    ///
    /// Takes the focus binding rather than leaving `.focused()` to the caller so the two can't be
    /// wired to different state, which would fail silently: the field would grow and nothing would
    /// move. Requires an enclosing `KeyboardFollowingScroll`; inert without one.
    func scrollsIntoViewWhenFocused<ID: Hashable>(_ scrollID: ID,
                                                  focused: FocusState<Bool>.Binding) -> some View {
        modifier(FocusScrollModifier(scrollID: scrollID, focused: focused))
    }
}

private struct FocusScrollModifier<ID: Hashable>: ViewModifier {
    let scrollID: ID
    let focused: FocusState<Bool>.Binding

    @Environment(\.focusScrollProxy) private var proxy

    func body(content: Content) -> some View {
        content
            .id(scrollID)
            .focused(focused)
            .background {
                // Measured from a clear backdrop rather than a `PreferenceKey`: the height is only
                // ever read here, so a preference would carry it up the tree just to hand it back.
                GeometryReader { geometry in
                    Color.clear.onChange(of: geometry.size.height) { oldHeight, newHeight in
                        guard FocusScroll.shouldScroll(from: oldHeight, to: newHeight,
                                                       focused: focused.wrappedValue)
                        else { return }
                        scrollToField()
                    }
                }
            }
            .onChange(of: focused.wrappedValue) { _, isFocused in
                if isFocused { scrollToField() }
            }
    }

    private func scrollToField() {
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy?.scrollTo(scrollID, anchor: .center)
        }
    }
}
