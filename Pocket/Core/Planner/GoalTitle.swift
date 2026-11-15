import Foundation

/// What a goal is **called on screen** (ADR 0298 D1) — so two goals made from *Play a specific song*
/// can be told apart wherever a goal is named, not only where a row has room for its song.
///
/// The template's title is a placeholder until a song is chosen: a goal still called *Play a specific
/// song* with *Sunday Morning* as its target reads **Play Sunday Morning**. A name the player typed is
/// theirs and is shown as typed. Worked out when it is shown rather than written into the store, so
/// goals saved before this rule existed read correctly with no migration, and a goal whose song
/// changes can never be left naming the old one.
///
/// Pure and Foundation-only. Both tiers use it: they share the templates (ADR 0171 D5), so they share
/// the placeholder.
enum GoalTitle {

    /// The title the song template seeds.
    static var placeholder: String { GoalTemplateLibrary.playSong.title }

    /// "Play Sunday Morning".
    static func forSong(_ songTitle: String) -> String { "Play \(songTitle)" }

    /// The name to show for a goal titled `title` whose target song is titled `songTitle`.
    static func display(_ title: String, songTitle: String?) -> String {
        let name = title.trimmingCharacters(in: .whitespaces)
        if let song = named(songTitle), name.isEmpty || name == placeholder {
            return forSong(song)
        }
        return name.isEmpty ? "Untitled goal" : name
    }

    /// The editor's name field after the target song changes from `old` to `new`.
    ///
    /// **The name follows the song while it is still one the app chose** — empty, the template's
    /// placeholder, or the name this rule gave the previous song. Anything else was typed, and is
    /// left alone. Clearing the song puts the placeholder back rather than keep naming a song the
    /// goal no longer has.
    static func following(_ title: String, from old: String?, to new: String?) -> String {
        let name = title.trimmingCharacters(in: .whitespaces)
        let chosenByApp = name.isEmpty || name == placeholder
            || named(old).map { name == forSong($0) } == true
        guard chosenByApp else { return title }
        if let song = named(new) { return forSong(song) }
        return name.isEmpty ? title : placeholder
    }

    /// A song title worth naming: an untitled song gives the placeholder nothing to say.
    private static func named(_ songTitle: String?) -> String? {
        guard let trimmed = songTitle?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
