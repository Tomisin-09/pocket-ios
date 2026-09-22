import SwiftData
import SwiftUI

/// Home's **Start here** card (ADR 0219) — the one door into the app's subject that a player
/// without Red Moon Pro can walk through.
///
/// It exists because a fresh install is not "in trial": `trialEndsAt` is read from a real StoreKit
/// expiration, so a player who has not subscribed is simply not Pro, and ADR 0144 D4's wall leaves
/// Practice, the Song library, Today's session and Jump back in all locked. Everything the app is
/// actually *for* sat behind a purchase made before hearing a note.
///
/// Split out of `HomeView.swift` for the same reason `HomeView+Resume` is — the 400-line file cap
/// and SwiftLint's `type_body_length`.
extension HomeView {

    /// The adopted starter track, if the player has already tapped the card.
    var starterTrack: Song? { songs.first(where: \.isStarterTrack) }

    /// Whether to draw the card at all — see `HomeFeed.shouldOfferStarterTrack` for why this is not
    /// gated on `isPro`.
    var offersStarterTrack: Bool {
        HomeFeed.shouldOfferStarterTrack(totalSongs: songs.count,
                                         hasStarterTrack: starterTrack != nil)
    }

    /// Whether `resumeCard` would be pointing at the very song the **Start here** card is already
    /// showing — in which case Home should draw one card, not two.
    ///
    /// It happens the moment a player practises the starter track and comes back: `resumeTarget`
    /// resolves to it, and the two cards then sit stacked, same title, same artist, one above the
    /// other. The starter-track card wins because it carries the same practice state *and* the
    /// eyebrow that explains what the song is doing there.
    func duplicatesStarterTrackCard(_ target: ResumeTarget) -> Bool {
        guard offersStarterTrack, case .song(let song) = target else { return false }
        return song.isStarterTrack
    }

    /// The card. A plain `Button`, **never `proGated`** — that is the entire point of it.
    ///
    /// Routing the tap through `openingSong` reuses the `navigationDestination` Home already owns
    /// for a single-file import, which is the correct shape twice over: it is bool-bound rather
    /// than `item:`-bound (a just-inserted `Song`'s `persistentModelID` flips on first autosave and
    /// would pop an item-based destination — ADR 0090), and landing on the waveform is exactly what
    /// an import does. Adopting the starter track *is* an import; it should arrive the same way.
    @ViewBuilder
    var starterTrackCard: some View {
        Button {
            haptic(.light)
            openStarterTrack()
        } label: {
            JumpBackInCard(content: starterTrackContent,
                           eyebrow: "A SONG TO START ON")
                .overlay(alignment: .topTrailing) {
                    if adoptingStarterTrack {
                        ProgressView()
                            .controlSize(.small)
                            .padding(16)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(adoptingStarterTrack)
        .accessibilityLabel("\(StarterTrack.title) by \(StarterTrack.artist), a song to start on")
        .accessibilityHint("Opens the practice screen")
    }

    /// Before the first tap there is no song, so there is nothing to report on the right — `.none`
    /// rather than `.mastery(nil)`, which would draw an em dash meaning *unrated* about a song the
    /// player does not yet have. Once it has been adopted it reads like any other song.
    private var starterTrackContent: JumpBackInCard.Content {
        JumpBackInCard.Content(title: StarterTrack.title,
                               subtitle: StarterTrack.artist,
                               practiced: starterTrack?.lastPracticed,
                               trailing: starterTrack.map { .mastery($0.mastery) } ?? .none)
    }

    /// Open the starter track, adopting it first if this is the first tap.
    ///
    /// The decode runs off the main actor for the same reason import's does — `WaveformExtractor`
    /// reads the whole file, and eighty seconds of AAC on the main thread is a visible stall.
    /// A failure surfaces through the same `importError` alert a real import uses rather than a
    /// second notice: from the player's side this *is* an import that didn't work.
    func openStarterTrack() {
        if let existing = starterTrack {
            openingSong = existing
            return
        }
        adoptingStarterTrack = true
        Task {
            defer { adoptingStarterTrack = false }
            do {
                let prepared = try await Task.detached(priority: .userInitiated) {
                    try SongImporter.prepareStarterTrack()
                }.value
                openingSong = SongImporter.importStarterTrack(prepared, into: context)
            } catch {
                importError = error.localizedDescription
            }
        }
    }
}
