import SwiftData
import SwiftUI

/// The route from a **linked song row inside a sheet** to that song's player (ADR 0172).
///
/// It exists because the destination cannot be reached the obvious way. `WaveformPracticeView`
/// rotates (ADR 0042 — the one screen in the app that does) and holds a keep-awake lease, and
/// neither survives being run inside a sheet. So the tap cannot push; it has to **stage** the song,
/// let the sheet close, and let the host push once it has gone — presenting into a *dismissing*
/// sheet drops the push, which `ExerciseLibraryView` already knew from its create-then-run flow.
///
/// Two hosts need exactly that dance (the exercise library and a standalone run screen), so it is
/// one value rather than two copies of two `@State` optionals and an ordering rule. The stepping is
/// pure and unit-tested; the view is a skin over it.
struct LinkedSongRoute: Equatable {
    /// Chosen while the sheet is still on screen.
    private(set) var pending: Song?
    /// Promoted once it has gone — this is what the push reads.
    private(set) var opening: Song?

    init() {}

    /// A song was tapped. The host closes its sheet in the same gesture; nothing is pushed yet.
    mutating func stage(_ song: Song) {
        pending = song
    }

    /// The sheet has finished dismissing — hand the staged song to the push, if there is one.
    /// A no-op when the sheet was closed any other way (Done, a swipe), so an ordinary dismissal
    /// never navigates anywhere.
    mutating func promote() {
        guard let pending else { return }
        opening = pending
        self.pending = nil
    }

    /// The push finished or was popped.
    mutating func clear() {
        opening = nil
    }
}

extension View {
    /// Attach the staged song's player to this screen's **own** navigation stack.
    ///
    /// Must sit on the host, never inside the sheet that raises it: a presentation attached to a row
    /// inside a sheet's `Form` dismisses that sheet instead of opening (see `ReferenceLinkEditing`).
    func linkedSongPlayer(_ route: Binding<LinkedSongRoute>) -> some View {
        modifier(LinkedSongPlayerRoute(route: route))
    }
}

private struct LinkedSongPlayerRoute: ViewModifier {
    @Binding var route: LinkedSongRoute
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        // Bool-bound rather than `.navigationDestination(item:)`: a model's `persistentModelID` can
        // flip temporary→permanent on a save, and item-based presentation reads that as an identity
        // change and pops the screen (ADR 0090).
        content.navigationDestination(isPresented: Binding(
            get: { route.opening != nil },
            set: { if !$0 { route.clear() } })) {
                if let song = route.opening {
                    WaveformPracticeView(song: song, context: context)
                }
            }
    }
}
