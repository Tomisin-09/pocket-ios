import Foundation

/// What a received song is called (ADR 0236 D5).
///
/// The receiver always gets a new song: nothing in their library is changed or merged. When they already
/// have one with the same title, the new one says whose copy it is, **`Low Road - Tomisin copy`**, or
/// **`Low Road - copy`** when the file carries no artist name. If that's taken too, it's numbered, the way
/// Finder numbers copies: `Low Road - Tomisin copy 2`.
///
/// **The match is on the title**, trimmed and ignoring case. A song's `sourceID` is minted fresh on every
/// import, so the same recording has a different id on every phone. Since a copy is made either way, the
/// title only decides the name, and audio is never compared.
///
/// Pure (AGENTS.md).
enum SongCopyName {

    /// The title the received song lands under.
    ///
    /// - Parameters:
    ///   - title: the song's title as sent.
    ///   - sender: the sender's artist name, if the file carried one.
    ///   - existing: every song title already in the receiver's library.
    static func title(for title: String, sender: String?, existing: [String]) -> String {
        let wanted = cleaned(title).isEmpty ? "Untitled song" : cleaned(title)
        let taken = Set(existing.map { cleaned($0).lowercased() })
        guard taken.contains(wanted.lowercased()) else { return wanted }
        let name = cleaned(sender ?? "")
        let base = name.isEmpty ? "\(wanted) - copy" : "\(wanted) - \(name) copy"
        guard taken.contains(base.lowercased()) else { return base }
        var number = 2
        while taken.contains("\(base) \(number)".lowercased()) { number += 1 }
        return "\(base) \(number)"
    }

    /// The titles several received songs land under, in order: a routine's songs (ADR 0236 D6). Each is
    /// named against the library **and the songs named before it**, so two songs sent with one title
    /// still land as two names.
    static func titles(for titles: [String], sender: String?, existing: [String]) -> [String] {
        var taken = existing
        return titles.map { sent in
            let name = title(for: sent, sender: sender, existing: taken)
            taken.append(name)
            return name
        }
    }

    private static func cleaned(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
