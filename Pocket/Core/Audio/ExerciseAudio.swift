import SwiftUI

/// The **exercise-audio seam** (ADR 0065 build 2, Slice 3 — scaffold). A boundary for *sonifying* a
/// fretboard drill — previewing the notes and, later, a looping accompaniment behind a practice run.
/// The audio backend does not exist yet; this factors the interface, the settings shape and the
/// injection point in **now**, so a real engine slots in by conforming to `ExerciseAudioEngine` and
/// injecting it into the environment — no call-site changes. Until then the silent default is in
/// place, so every surface can read `isAvailable` to show a "coming soon" affordance honestly.
///
/// Deliberately thin and un-plumbed: no dead audio machinery, just the shape of the boundary.
/// `Sendable` so it can back a SwiftUI `EnvironmentKey` under Swift 6 strict concurrency.
protocol ExerciseAudioEngine: Sendable {
    /// Whether a real backend is wired in. The silent placeholder returns `false`, so UI can disable
    /// its sound affordances and read as "coming soon".
    var isAvailable: Bool { get }

    /// Preview a whole drill from the top at a tempo — what a "hear it" button would trigger.
    func preview(_ drill: FretboardDrill, tempoBPM: Int)

    /// Sound a single note as the walking board reaches it — the per-onset hook a running board would
    /// call. A no-op today; wired when audio lands.
    func sound(_ note: FretNote)

    /// Start / stop a looping accompaniment behind a practice run.
    func startAccompaniment(_ settings: AccompanimentSettings)
    func stopAccompaniment()
}

/// How a future accompaniment plays behind an exercise. Persistable so a per-exercise choice can be
/// stored the day audio ships, without a later schema change.
struct AccompanimentSettings: Equatable, Codable {
    var isEnabled: Bool
    var style: AccompanimentStyle

    init(isEnabled: Bool = false, style: AccompanimentStyle = .none) {
        self.isEnabled = isEnabled
        self.style = style
    }
}

/// The accompaniment texture behind an exercise (placeholder vocabulary for the future backend).
enum AccompanimentStyle: String, CaseIterable, Codable, Identifiable {
    case none
    case drone   // a sustained root/fifth pad under the run
    case chords  // the exercise's harmony comped in time

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .drone: return "Drone"
        case .chords: return "Chords"
        }
    }
}

/// The no-op engine in place until a real backend arrives — every method does nothing and
/// `isAvailable` is `false`.
struct SilentExerciseAudio: ExerciseAudioEngine {
    var isAvailable: Bool { false }
    func preview(_ drill: FretboardDrill, tempoBPM: Int) {}
    func sound(_ note: FretNote) {}
    func startAccompaniment(_ settings: AccompanimentSettings) {}
    func stopAccompaniment() {}
}

private struct ExerciseAudioKey: EnvironmentKey {
    static let defaultValue: ExerciseAudioEngine = SilentExerciseAudio()
}

extension EnvironmentValues {
    /// The exercise-audio engine for the current view tree — silent by default. Inject a real
    /// implementation at the app root when audio ships: `.environment(\.exerciseAudio, RealEngine())`.
    var exerciseAudio: ExerciseAudioEngine {
        get { self[ExerciseAudioKey.self] }
        set { self[ExerciseAudioKey.self] = newValue }
    }
}

/// A **sound-preview affordance** for the fretboard editors — the visible home of the audio feature.
/// It reads the injected engine: disabled and captioned "Sound soon" while the silent placeholder is
/// in place, and a live "Preview" button once a real engine is injected. No audio logic of its own.
struct SoundPreviewButton: View {
    let drill: FretboardDrill
    var tempoBPM: Int = 60
    var tint: Color = PocketColor.practice
    @Environment(\.exerciseAudio) private var audio

    var body: some View {
        Button {
            audio.preview(drill, tempoBPM: tempoBPM)
            haptic(.light)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: audio.isAvailable ? "speaker.wave.2" : "speaker.slash")
                Text(audio.isAvailable ? "Preview" : "Sound soon")
            }
            .font(.futura(.caption, weight: .semibold))
            .foregroundStyle(audio.isAvailable ? tint : PocketColor.textSecondary)
        }
        .buttonStyle(.borderless)
        .disabled(!audio.isAvailable)
        .accessibilityLabel("Sound preview")
        .accessibilityHint(audio.isAvailable ? "Hear the run" : "Audio preview coming soon")
    }
}
