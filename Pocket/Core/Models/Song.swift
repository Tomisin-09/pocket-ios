import Foundation
import SwiftData

/// The practice-data aggregate, persisted with SwiftData (and CloudKit-syncable in
/// Phase 4): a `Song` — an imported file identified by its `SongRef` — with its
/// `Loop`s and `Marker`s. Transient UI state (capture drafts, the live playhead,
/// zoom) is *not* here; it lives on `WaveformPracticeModel`. See ADR 0011.
@Model
final class Song {
    var title: String
    var artist: String
    var key: String
    /// `nil` when the tempo is unknown — a normal state (ADR 0004).
    var bpm: Int?
    var proficiency: Int          // 0–5 stars
    var progression: String
    var collections: [String]
    var duration: TimeInterval
    /// Per-bar amplitudes for the detail waveform (0...1), extracted at import.
    var amplitudes: [Double]

    // Import identity (`SongRef`), flattened for storage. `bookmark == nil` marks
    // the generated demo sample (no real file behind it).
    var sourceID: String
    var sourceRaw: String
    var bookmark: Data?

    @Relationship(deleteRule: .cascade, inverse: \Loop.song) var loops: [Loop] = []
    @Relationship(deleteRule: .cascade, inverse: \Marker.song) var markers: [Marker] = []

    init(title: String, artist: String = "", key: String = "", bpm: Int? = nil,
         proficiency: Int = 0, progression: String = "", collections: [String] = [],
         duration: TimeInterval, amplitudes: [Double] = [], ref: SongRef) {
        self.title = title
        self.artist = artist
        self.key = key
        self.bpm = bpm
        self.proficiency = proficiency
        self.progression = progression
        self.collections = collections
        self.duration = duration
        self.amplitudes = amplitudes
        self.sourceID = ref.id
        self.sourceRaw = ref.source.rawValue
        self.bookmark = ref.bookmark
    }

    /// The import identity. `bookmark == nil` ⇒ the generated demo sample.
    var ref: SongRef {
        SongRef(id: sourceID, source: SongRef.Source(rawValue: sourceRaw) ?? .localFile, bookmark: bookmark)
    }

    var loopsByStart: [Loop] { loops.sorted { $0.start < $1.start } }
    var markersByTime: [Marker] { markers.sorted { $0.seconds < $1.seconds } }
}

@Model
final class Loop {
    /// Stable business id — used for active/selection tracking in the view (the
    /// SwiftData `persistentModelID` is unstable before insert).
    var uid: UUID
    /// User-given name; falls back to the time range when empty.
    var name: String
    /// Bounds as fractions of the song (0...1), edited on the waveform in Fine mode.
    var start: Double
    var end: Double
    var speed: Double
    var repeats: Int
    var song: Song?

    init(name: String, start: Double, end: Double, speed: Double, repeats: Int) {
        self.uid = UUID()
        self.name = name
        self.start = start
        self.end = end
        self.speed = speed
        self.repeats = repeats
    }

    var startSeconds: TimeInterval { (song?.duration ?? 0) * start }
    var endSeconds: TimeInterval { (song?.duration ?? 0) * end }
}

@Model
final class Marker {
    var uid: UUID
    var seconds: TimeInterval
    var label: String
    var song: Song?

    init(seconds: TimeInterval, label: String) {
        self.uid = UUID()
        self.seconds = seconds
        self.label = label
    }
}
