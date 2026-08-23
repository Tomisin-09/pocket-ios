import Foundation

/// The per-row ⓘ copy, centralised the way `PracticeFieldInfo` is for the loop sheet. Keeping the
/// explanations off the section footers and on each row's `FieldInfoLabel` is what lets the
/// destinations stay scannable while the nuance stays a tap away.
///
/// Its own file since ADR 0162 — the copy is shared across several Settings destinations now, so it
/// belongs to none of them.
enum SettingsInfo {
    static let haptics =
        "Light taps that confirm gestures like setting a loop or tapping tempo."
    static let analytics =
        "Counts of which features get used — how often a loop gets made, which exercises get built. "
        + "Anonymous and not joined up across sessions, so it can't be traced back to you. Never "
        + "your audio, notes, song names or artist name."
    static let countIn =
        "A count-in before a tempo climb begins, so you can settle in before playing."
    static let keepScreenAwake =
        "Stops the screen locking while you play along hands-free."
    static let strumClick =
        "For a strumming drill, the metronome plays the pattern's rhythm (down/up/accent). Turned "
        + "off, it's a plain click you strum the rhythm against."
    static let routineAutoStart =
        "In a routine, each block after the first starts on its own — the first always waits for you."
    static let routineAutoAdvance =
        "When a block finishes, a Done screen lets you rate how it felt and jot a note. Turn this on "
        + "to skip it and go straight to the next block."
    static let routineRest =
        "The breather between blocks."
    static let routineSongLoop =
        "A song block loops as an open jam and moves on only when you skip. Off plays it through once, "
        + "then auto-advances."
    static let transportLoopOnLeft =
        "Big Loop and Marker buttons flank the transport bar while idle. Marker sits on the left and "
        + "Loop on the right by default — turn this on to swap them."
    static let minimap =
        "The full-song overview strip under the waveform. Off gives the waveform and loops a little "
        + "more room."
    static let markerLabels =
        "Floats a marker's name over the timeline as you play up to it. Off keeps labels in the "
        + "Markers panel only."
    static let zoomFollowsPlayhead =
        "Pinch-zoom normally keeps the spot under your fingers still. Turn this on to have the "
        + "window re-center on the playhead as you zoom instead."
    static let songsInBackup =
        "Your imported song files ride along in your device backup, so a restored phone plays them "
        + "straight away. Turning this off makes backups much smaller, and means a restored phone "
        + "needs each song pointed at its file again. Your recordings are always backed up."
    static let reclaimSpace =
        "Deletes audio files left behind by songs and takes you have already removed. It never "
        + "touches a song or a take you still have."
    static let exportRecordings =
        "Your takes are the one part of an archive nothing else can rebuild, and the largest part by "
        + "far. Leave this on unless all you want is your notes and settings."
    static let animateExercises =
        "A moving highlight walks the exercise in time — the notes on the fretboard, the strokes on "
        + "the strum lane. Always off when your device has Reduce Motion on."
}
