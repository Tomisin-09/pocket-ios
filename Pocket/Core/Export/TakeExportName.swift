import Foundation

/// What an exported take is called (ADR 0236 D2, amended by ADR 0307 D6): **its title if it has one,
/// otherwise its owner caption and its number, then the date** — `Slow Bend · Chorus · Take 3 · 1 Oct
/// 2026`. A take recorded against nothing has no caption, so it is `Take 3 · 1 Oct 2026`.
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
    ///   - takeNumber: the take's number in its count (ADR 0307). A take with none exports as it did
    ///     before 0307.
    static func stem(title: String?, ownerLabel: String?, takeNumber: Int? = nil, createdAt: Date,
                     locale: Locale = .autoupdatingCurrent,
                     timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let date = createdAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted,
                                                        locale: locale, timeZone: timeZone))
        let numbered = takeNumber.map { number in
            [nonEmpty(ownerLabel), TakeNumbering.name(number)].compactMap { $0 }.joined(separator: " · ")
        }
        let name = nonEmpty(title)
            ?? numbered
            ?? nonEmpty(ownerLabel)
            ?? "Take"
        return "\(name) · \(date)"
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
