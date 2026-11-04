import Foundation

/// **The files of one import** (ADR 0290): every file picked, and how it went, for the import sheet's rows.
/// `SongImportModel` moves each one along as it's read; this holds no SwiftData, so what each row says, the
/// sheet's title and the outcome are unit-tested.
struct SongImportBatch: Equatable {

    enum State: Equatable {
        case waiting
        case reading
        case added
        /// Skipped, with the reason in words the player can act on.
        case skipped(String)
    }

    struct File: Equatable, Identifiable {
        /// Its place in the pick.
        let id: Int
        /// The title it imports under: the file name without its extension.
        let name: String
        var state: State = .waiting
    }

    private(set) var files: [File]

    init(names: [String]) {
        files = names.enumerated().map { File(id: $0.offset, name: $0.element) }
    }

    mutating func reading(_ id: Int) { set(id, .reading) }
    mutating func added(_ id: Int) { set(id, .added) }
    mutating func skipped(_ id: Int, because error: Error) { set(id, .skipped(Self.reason(for: error))) }

    /// Every file has been read, whether it was added or skipped.
    var isFinished: Bool {
        files.allSatisfy { $0.state != .waiting && $0.state != .reading }
    }

    /// What happened, in the shape the rest of the app already reads (`SongImportSummary`).
    var summary: SongImportSummary {
        SongImportSummary(imported: files.filter { $0.state == .added }.count,
                          failedNames: files.compactMap { file in
                              if case .skipped = file.state { return file.name }
                              return nil
                          })
    }

    /// The sheet's title: *Importing 2 of 5* while it runs, counting the file being read, then what
    /// happened: *Songs added*, or *Some files were skipped*.
    var title: String {
        guard !isFinished else { return summary.title }
        let reached = files.filter { $0.state != .waiting }.count
        return "Importing \(max(reached, 1)) of \(files.count)"
    }

    /// Why a file was skipped, said so the player knows whether trying again could help.
    static func reason(for error: Error) -> String {
        if let error = error as? SongImporter.ImportError, error == .accessDenied {
            return "Red Moon wasn't allowed to open it. Try picking it again."
        }
        if let error = error as? WaveformExtractor.ExtractError, error == .emptyFile {
            return "There's no audio in it."
        }
        return "It couldn't be read. A copy-protected file can't be imported."
    }

    private mutating func set(_ id: Int, _ state: State) {
        guard files.indices.contains(id) else { return }
        files[id].state = state
    }
}
