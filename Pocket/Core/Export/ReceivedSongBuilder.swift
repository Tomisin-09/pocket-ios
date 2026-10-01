import Foundation
import SwiftData

/// A song that arrived in a pack (ADR 0236 D4), read, checked, its audio unpacked, and **not yet written
/// anywhere**: the preview shows this, and Add lands it.
struct ReceivedSong: Equatable, Sendable {
    var record: SongRecord
    /// The song's audio, unpacked into `staging`.
    var audio: URL
    /// The folder the pack was unpacked into, removed once the song lands or is turned down.
    var staging: URL
    /// The sender's artist name, if the file carried one (D7).
    var senderName: String?
    var appVersion: String
    var exportedAt: Date

    var displayTitle: String {
        let title = record.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled song" : title
    }
}

/// A received song as it lands inside a routine (ADR 0236 D6): the new song, and how the file named it
/// and its loops, so the routine's blocks can be pointed at the new ones. The file's ids are join keys
/// inside that one payload and are never written to a model.
struct LandedSong {
    /// The `sourceID` the sender's file gave the song, which a song block names.
    var sentSourceID: String
    var song: Song
    /// Each new loop, by the uid the sender's file gave it, which a loop block names.
    var loops: [UUID: Loop]
}

/// A received song becomes the receiver's own (ADR 0236 D4, D5).
///
/// The same rules as the receive door for a routine (ADR 0188 D1): **every uid is minted fresh**, so
/// nothing a stranger's file names can collide with a row here, and nothing the sender measured lands,
/// even if a file carries it. The audio is copied in as an import is (0148), and the song is an imported
/// song from then on.
@MainActor
enum ReceivedSongBuilder {

    /// The received song as it lands: the prepared import (`SongImporter.prepareReceived`), titled by D5,
    /// with the record's metadata, grid, loops and markers. Not inserted; the caller does that.
    static func song(from received: ReceivedSong, prepared: SongImporter.Prepared, title: String) -> Song {
        landing(received, prepared: prepared, title: title).song
    }

    /// A song that arrived inside a routine (ADR 0236 D6), built as one sent on its own is, with the map
    /// the routine's blocks are bound through. Not inserted.
    static func landing(_ received: ReceivedSong, prepared: SongImporter.Prepared, title: String) -> LandedSong {
        let song = Song(title: title, duration: prepared.duration, amplitudes: prepared.amplitudes,
                        dateAdded: .now,
                        ref: SongRef(id: prepared.sourceID, source: .localFile, bookmark: nil),
                        audioFileName: prepared.audioFileName)
        let loops = apply(received.record, to: song)
        return LandedSong(sentSourceID: received.record.sourceID, song: song, loops: loops)
    }

    /// Everything the record carries that is the song's own: metadata, the tempo and beat grid, every
    /// marker and every loop, with new uids, and links between them followed to the new ones.
    ///
    /// Returns each new loop by the uid the file gave it, for a routine's blocks to find (ADR 0236 D6).
    @discardableResult
    static func apply(_ record: SongRecord, to song: Song) -> [UUID: Loop] {
        song.artist = record.artist
        song.album = record.album
        song.genre = record.genre
        song.year = record.year
        song.key = record.key
        song.bpm = record.bpm
        song.preciseBPM = record.preciseBPM
        song.downbeatSeconds = record.downbeatSeconds
        song.extraDownbeatSeconds = record.extraDownbeatSeconds
        song.beatsPerBar = record.beatsPerBar
        song.noteValue = record.noteValue
        song.showsGridlines = record.showsGridlines

        // Markers first, so a loop that repeats through a section and a section that's the same as
        // another can be pointed at the new uids.
        var markerUIDs: [UUID: UUID] = [:]
        let markers = record.markers.map { saved -> Marker in
            let marker = Marker(seconds: saved.seconds, label: saved.label)
            markerUIDs[saved.uid] = marker.uid
            marker.startsSection = saved.startsSection ?? false
            return marker
        }
        for (marker, saved) in zip(markers, record.markers) {
            marker.sameAsUID = saved.sameAsUID.flatMap { markerUIDs[$0] }
        }
        song.markers = markers
        let loops = record.loops.map { ($0.uid, loop(from: $0, markers: markerUIDs)) }
        song.loops = loops.map(\.1)
        // A file that names one uid twice keeps the first: a block bound to either reaches a loop of this
        // song, which is all the receiver can ask of a file it didn't write.
        return Dictionary(loops, uniquingKeysWith: { first, _ in first })
    }

    /// One loop's settings, with a new uid. Mastery, speeds reached, the command tempo, the piece and its
    /// versions are **not read**, whatever the file says (0188 D5): the sender strips them, and a receive
    /// doesn't trust that it did.
    static func loop(from record: LoopRecord, markers: [UUID: UUID]) -> Loop {
        let made = Loop(name: record.name, start: record.start, end: record.end,
                        speed: record.speed, repeats: record.repeats)
        made.loopTypeRaw = record.loopTypeRaw
        made.tags = record.tags
        made.isBackingTrack = record.isBackingTrack
        made.targetSpeedOverride = record.targetSpeedOverride
        made.automatorEnabled = record.automatorEnabled
        made.automatorTargetSpeed = record.automatorTargetSpeed
        made.automatorStepCount = record.automatorStepCount
        made.automatorLoopsPerStep = record.automatorLoopsPerStep
        made.rampWarmupSteps = record.rampWarmupSteps
        made.rampReachSteps = record.rampReachSteps
        made.rampBackoffSteps = record.rampBackoffSteps
        made.rampRepsPerStep = record.rampRepsPerStep
        made.rampDwellIntervals = record.rampDwellIntervals
        made.includeBackoff = record.includeBackoff
        made.backoffSpeedOverride = record.backoffSpeedOverride
        made.includeWarmup = record.includeWarmup ?? true
        made.includeReach = record.includeReach ?? true
        made.rampWarmupHold = record.rampWarmupHold ?? 1
        made.rampReachHold = record.rampReachHold ?? 1
        made.rampBackoffHold = record.rampBackoffHold ?? 1
        made.colorIndex = record.colorIndex
        made.customColorHex = record.customColorHex
        made.repeatsToSectionEnd = record.repeatsToSectionEnd ?? false
        // Through a later section: that section's marker, by its new uid. One the file doesn't carry
        // reads as its own section's end, as the map reads any it can't find (ADR 0232 D15).
        made.repeatsTo = switch SongMap.RepeatsTo(stored: record.repeatsTo) {
        case .through(let old): markers[old].flatMap { SongMap.RepeatsTo.through($0).stored }
        case let other: other.stored
        }
        return made
    }
}
