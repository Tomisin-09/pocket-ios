import Foundation

/// Mock fixtures for the waveform practice screen skeleton. This is throwaway
/// presentation data so the layout can be designed against realistic content;
/// it is replaced by the real audio-analysis + persistence layer in later
/// phases. Kept free of SwiftUI so the view file stays focused on layout.
enum WaveformMock {

    struct Song {
        let title: String
        let artist: String
        let key: String
        let bpm: Int
        /// 0–5 stars.
        let proficiency: Int
        let progression: String
        let collections: [String]
        let duration: TimeInterval

        /// Per-bar amplitudes for the detail waveform, 0...1.
        let amplitudes: [Double]
        /// Playhead position as a fraction of the song.
        let playheadFraction: Double
        /// The slice of the song the detail waveform is showing (minimap viewport).
        let viewport: (start: Double, end: Double)

        let loops: [Loop]
        let markers: [Marker]

        var playheadSeconds: TimeInterval { duration * playheadFraction }
        var activeLoop: Loop? { loops.first }
    }

    struct Loop: Identifiable {
        let id = UUID()
        /// User-given name; editable. Falls back to the time range when empty.
        var name: String
        /// Bounds as fractions of the song (0...1). Edited via waveform gestures,
        /// not the edit sheet, so they stay `let` here.
        let start: Double
        let end: Double
        var speed: Double
        var repeats: Int

        let duration: TimeInterval

        var startSeconds: TimeInterval { duration * start }
        var endSeconds: TimeInterval { duration * end }
    }

    struct Marker: Identifiable {
        let id = UUID()
        let seconds: TimeInterval
        var label: String
    }

    static let song: Song = {
        let duration: TimeInterval = 144 // 2:24
        return Song(
            title: "Little Wing",
            artist: "Jimi Hendrix",
            key: "G minor",
            bpm: 76,
            proficiency: 3,
            progression: "Groove / lead phrasing",
            collections: ["Hendrix study", "Bends & vibrato"],
            duration: duration,
            amplitudes: amplitudes(count: 120),
            playheadFraction: 0.35,
            viewport: (0.20, 0.55),
            loops: [
                Loop(name: "Verse riff", start: 0.29, end: 0.47, speed: 0.75, repeats: 4, duration: duration),
                Loop(name: "Chorus bend", start: 0.62, end: 0.71, speed: 1.0, repeats: 2, duration: duration)
            ],
            markers: [
                Marker(seconds: 18, label: "Intro turnaround"),
                Marker(seconds: 75, label: "Tricky bend")
            ]
        )
    }()

    /// Deterministic, organic-looking amplitudes so the waveform reads as music
    /// rather than noise — no randomness, so screenshots are stable.
    private static func amplitudes(count: Int) -> [Double] {
        (0..<count).map { index in
            let phase = Double(index)
            let envelope = 0.55 + 0.4 * sin(phase * 0.05)
            let detail = abs(sin(phase * 0.5) * cos(phase * 0.13)) + 0.3 * abs(sin(phase * 1.1))
            return min(1.0, max(0.06, envelope * detail))
        }
    }
}
