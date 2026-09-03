import CoreTransferable
import Foundation
import UniformTypeIdentifiers

extension UTType {

    /// The file a piece of practice travels in — `.redmoonpractice` (ADR 0188 D3).
    ///
    /// `exportedAs`, not `importedAs`: this app **defines** the type, and the declaration it reads
    /// lives in `Pocket/Resources/Info.plist` under `UTExportedTypeDeclarations`. `UTType(exportedAs:)`
    /// traps at launch if that declaration is missing, which is the behaviour you want — a file type
    /// the system has never been told about is not a file type.
    ///
    /// The identifier is derived from the bundle id, which is why it reads `pocket` in lower case.
    /// That is the target and the bundle id and nothing a player ever sees; what the system shows
    /// beside the file is the type's description, **Red Moon practice**, set in `Info.plist`.
    ///
    /// **Not `CFBundleDocumentTypes`, yet.** Declaring the app as a *handler* for this type is what
    /// puts Red Moon in the system's Open-with list, and until ADR 0188's S2 ships there is nothing
    /// behind that door. Advertising a capability the app does not exercise is the thing AGENTS.md
    /// forbids, so the handler declaration lands with the code that honours it.
    static let redMoonPractice = UTType(exportedAs: "click.decooperations.pocket.practice")
}

/// One shared routine on its way to the share sheet (ADR 0188 S1).
///
/// Carries the payload rather than encoded bytes, so building it costs a walk over the blocks and
/// nothing more — `ShareLink` reconstructs its item on every pass of the view's body, and JSON
/// encoding on that path would be a cost paid for a sheet that may never open. The encode happens in
/// the transfer representation instead, which the system calls once, asynchronously, when the player
/// has actually chosen where the file is going.
struct SharedPracticeFile: Transferable, Sendable, Equatable {

    /// What the file will contain.
    var payload: SharedPractice

    /// The name the receiver sees before they open it, extension included.
    var fileName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .redMoonPractice) {
            try ArchiveCoding.encode($0.payload)
        }
        .suggestedFileName { $0.fileName }
    }

    /// A file name from a routine's own name: its words, hyphenated, with anything a file system
    /// would rather not see removed.
    ///
    /// Not `title.replacingOccurrences` over a blocklist — a blocklist of illegal characters is a
    /// list somebody has to keep correct. This keeps what it knows is safe and drops the rest, so an
    /// emoji, a slash or a routine named entirely in a script this happens not to handle all end at
    /// the same defensible place rather than at a file the share sheet refuses.
    static func fileName(for routineName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let stem = routineName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { result, character in
                // Collapse runs, so "Morning  warm-up!!" is one hyphen between words rather than four.
                if character == "-" && result.last == "-" { return }
                result.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(stem.isEmpty ? "routine" : stem).redmoonpractice"
    }
}
