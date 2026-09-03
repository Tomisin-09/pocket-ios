import SwiftUI
import UniformTypeIdentifiers

/// **Receive a routine** (ADR 0188 S2) — the in-app door, and the second of the two.
///
/// Split into its own file to keep `RoutineLibraryView.swift` under the 400-line cap, the same way
/// `RoutineDetailView+Share.swift` holds the sending control for the same reason.
///
/// The first door is tap-to-open, which is the one a teacher actually uses: they send a file, the
/// player taps it. This one exists because the file does not always arrive as a tap — it can be
/// sitting in Files, in iCloud Drive, or in a folder the player saved it to a week ago — and
/// "you had to open it from the message it came in" is a door that closes behind you. It does no work
/// of its own: it picks a URL and hands it to the same `RoutineReceiveHost` the tap goes through.
extension RoutineLibraryView {

    /// The menu row, beside *Generate a quick session* in the shared list-options menu.
    ///
    /// On the options menu rather than the nav bar, per ADR 0126: nothing on a nav bar may vary in
    /// width, and this is a labelled secondary action — a bare glyph for "open a file somebody sent
    /// you" would be unreadable. Locked for a free player in the same way as everything else on this
    /// screen, so the lock is visible before the picker rather than after it.
    @ViewBuilder
    var receiveRoutineButton: some View {
        Button {
            // Gated here **and** in the host. Not redundancy: the host is the only possible gate for
            // a tapped file, which has no button to guard, and guarding here is what stops a free
            // player picking a file and then being told it was never going to work — the repeated-guard
            // style this screen already uses for New, Play, Edit, Duplicate and Generate.
            guard AccessPolicy.canAuthorRoutine(isPro: isPro) else {
                return presentPaywall(.routine(.receive))
            }
            importingRoutine = true
            haptic(.light)
        } label: {
            Label("Receive a routine…", systemImage: isPro ? "square.and.arrow.down" : "lock.fill")
        }
    }
}

extension View {
    /// The document picker for a `.redmoonpractice` file, filtered to the one type the app declares
    /// (ADR 0188 D3) — so a player browsing Files sees their shared routines and nothing else
    /// selectable.
    ///
    /// A `View` extension so `UniformTypeIdentifiers` and the type itself stay in this file rather
    /// than in the library screen, which cares about neither. Follows
    /// `ReferenceAttachmentPresentation.swift:111`'s shape: a picker failure needs no alert of its
    /// own — cancelling is the common "failure" and the player already knows they cancelled.
    func routineFileImporter(isPresented: Binding<Bool>,
                             onPick: @escaping @MainActor (URL) -> Void) -> some View {
        fileImporter(isPresented: isPresented, allowedContentTypes: [.redMoonPractice]) { result in
            if case let .success(url) = result { onPick(url) }
        }
    }
}
