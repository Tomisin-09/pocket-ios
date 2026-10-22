import Observation

/// **Where a song shared from another app opens** (ADR 0273 D3).
///
/// The receive host sits at the app's root and imports the file; Home owns the navigation stack the
/// song's waveform is pushed onto. This is how the two meet. Home says whether it can open a song
/// right now, and the host either hands the song over or, when Home can't, says where it went.
///
/// **It is a mailbox, like `NotificationRouter`**: the song is taken once and cleared, so Home
/// reappearing never opens it a second time. Unlike that router it isn't a singleton: both ends are
/// views, so the host owns it and puts it in the environment.
@MainActor
@Observable
final class SharedSongArrival {

    /// Whether Home is on top, with nothing of its own over it or on its way. Written by Home.
    var homeCanOpen = false

    /// The song to open, until Home takes it.
    private(set) var pending: Song?

    func open(_ song: Song) {
        pending = song
    }

    /// Take the pending song, if any, and clear it.
    func take() -> Song? {
        defer { pending = nil }
        return pending
    }
}
