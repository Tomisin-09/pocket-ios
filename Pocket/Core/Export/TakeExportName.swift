import Foundation

/// What an exported take is called (ADR 0236 D2): **its title if it has one, otherwise its owner
/// caption, then the date** — `Slow Bend · Chorus · 1 Oct 2026`.
///
/// A take is stored as `<uid>.m4a`, which says nothing to whoever receives it. The Journal already
/// knows what each take was recorded against and shows it under the row, so the file says the same
/// thing. The date is what tells two takes of one loop apart in a folder, and it is written the way
/// the player's locale writes a date, since the player is who reads it.
///
/// Pure and Foundation-only (AGENTS.md).
enum TakeExportName {

    /// The name before the extension.
    ///
    /// - Parameters:
    ///   - title: the player's name for the take (`Recording.title`), if they gave it one.
    ///   - ownerLabel: the Journal's caption for what it was recorded against, live or the snapshot a
    ///     take keeps when its owner is deleted (ADR 0151).
    static func stem(title: String?, ownerLabel: String?, createdAt: Date,
                     locale: Locale = .autoupdatingCurrent,
                     timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let named = [title, ownerLabel]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        let date = createdAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted,
                                                        locale: locale, timeZone: timeZone))
        return "\(named ?? "Take") · \(date)"
    }
}
