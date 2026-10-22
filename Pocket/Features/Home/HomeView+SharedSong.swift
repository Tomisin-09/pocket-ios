import SwiftUI

/// Home's half of a song shared from another app (ADR 0273 D3). The receive host at the root imports
/// the file; this decides whether Home can open it, and opens it.
extension HomeView {

    /// Whether a shared song may be pushed now: Home on top, and nothing of Home's own over it or on its
    /// way. A song arriving while a routine runs, or on any other screen, stays in the library and the
    /// host says so. Pushing past a running routine is the leave ADR 0272 makes the player confirm.
    ///
    /// `openingSong` is in the list for a second reason: a song already open from Home is the same
    /// destination, and swapping the song under it would leave that screen's state on the wrong song.
    var canOpenSharedSong: Bool {
        homeIsOnTop
            && openingSong == nil && openingRoutine == nil && !showingLibrary
            && !showingMetronome && !showingNamePrompt && !showingIntake
            && !importing && importModel.progress == nil && !adoptingStarterTrack
            && notificationRouter.pendingRoutineUID == nil
    }

    /// Open the song the host handed over, the way **+** opens a single import: straight onto its
    /// waveform, through the destination Home already owns.
    func openSharedSong() {
        guard let song = sharedSongArrival?.take() else { return }
        openingSong = song
    }
}
