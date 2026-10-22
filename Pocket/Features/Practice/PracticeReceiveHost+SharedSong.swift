import SwiftData
import SwiftUI

/// A shared song opened from the receive host's *Added* alert (ADR 0273 D3): the song player, over the
/// screen the player was on, so closing it puts them back there. The player's back chevron dismisses,
/// and inside a cover that closes the cover.
///
/// A cover and not a sheet: the song player rotates (ADR 0042) and holds a keep-awake lease, and
/// neither survives a sheet (ADR 0172). Bool-bound for the identity-flip reason every song
/// presentation is (ADR 0090).
struct SharedSongCover: ViewModifier {
    @Binding var song: Song?
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: Binding(get: { song != nil }, set: { if !$0 { song = nil } })) {
            if let song {
                NavigationStack { WaveformPracticeView(song: song, context: context) }
            }
        }
    }
}

#if DEBUG
/// The UI tests' ways in to the receive door, each opened as a tapped file is: a pack built at launch
/// (ADR 0236 D8), and an audio file shared from another app (ADR 0273), at launch or on the first return
/// from the background, over whatever screen the test left open.
struct ReceiveDoorTestFiles: ViewModifier {
    let open: @MainActor (URL) -> Void
    /// The app has been in the background since launch, so the next return is the share arriving.
    @State private var wentToBackground = false
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .task { if let pack = ReceivedPackSeed.packIfAsked() { open(pack) } }
            .task { if let audio = SharedAudioSeed.fileIfAsked() { open(audio) } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { wentToBackground = true }
                guard phase == .active, wentToBackground,
                      let audio = SharedAudioSeed.fileOnReturnIfAsked() else { return }
                open(audio)
            }
    }
}
#endif
