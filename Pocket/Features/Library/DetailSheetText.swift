import Foundation

/// What the detail sheets derive to show (ADR 0258): song details' facts line under the title, and the
/// values the sheets' category rows carry so the common visit ends without opening one (ADR 0162 D3).
/// Pure, so the joins and the plurals are pinned by tests rather than only seen on a device.
enum DetailSheetText {

    /// `F# Minor · 83 BPM · 3:24`, leaving out whatever is unknown — a song with no key set reads
    /// `83 BPM · 3:24`, not `— · 83 BPM · 3:24`. Empty when nothing is known.
    static func facts(key: String?, tempo: String?, length: String?) -> String {
        [key, tempo, length]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// The **Progress** row's value: how many loops the song has, which is what everything on that
    /// screen is made of.
    static func loops(_ count: Int) -> String {
        switch count {
        case 0: "No loops"
        case 1: "1 loop"
        default: "\(count) loops"
        }
    }

    /// The **References** row's value. Links and files are counted apart because both live there
    /// (ADR 0167 phase 2), and *2 links* for a link and a PDF would be wrong.
    static func references(links: Int, files: Int) -> String {
        let parts = [counted(links, "link"), counted(files, "file")].compactMap { $0 }
        return parts.isEmpty ? "None" : parts.joined(separator: " · ")
    }

    /// Edit loop's **Works on & tags** row: the skills Works on lists (stated and from tags) and the
    /// tags, counted apart.
    static func worksOn(skills: Int, tags: Int) -> String {
        let parts = [counted(skills, "skill"), counted(tags, "tag")].compactMap { $0 }
        return parts.isEmpty ? "None" : parts.joined(separator: " · ")
    }

    private static func counted(_ count: Int, _ noun: String) -> String? {
        count == 0 ? nil : "\(count) \(noun)\(count == 1 ? "" : "s")"
    }
}
