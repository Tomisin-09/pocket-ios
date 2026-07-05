import Foundation

/// The runtime **renderer** an exercise plays on (ADR 0065) — the visual/interactive surface the
/// run screen shows over the shared metronome/ramp engine. A small, **closed** set: one case per
/// surface that actually exists in code. It is *derived* from the user-facing `ExerciseTemplate`
/// (`template.renderer`), never stored on its own — the template is the single persisted axis, and
/// several templates (Scales, Chords, …) legitimately share the `.metronome` renderer until their
/// own surface ships. Adding a renderer is a deliberate, ADR-worthy change, not an open extension.
enum ExerciseKind: String, CaseIterable, Identifiable, Codable {
    /// The universal underlay and the fallback: today's beat dots + the ramp staircase. Every
    /// template that has no bespoke surface yet renders here.
    case metronome
    /// An animated down / up / rest arrow lane, the current slot lit — driven by `StrumPattern`.
    case strumming

    var id: String { rawValue }
}
