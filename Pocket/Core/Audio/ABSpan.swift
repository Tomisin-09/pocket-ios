import Foundation

/// Pure state machine for the **A/B span** — the loop-creation primitive (ADR 0041).
///
/// Models the play-along tap cycle and the span's ordering, free of
/// SwiftUI/AVFoundation so the cycle — the logic that breaks silently without
/// coverage — is exhaustively unit-tested (AGENTS.md). The associated `Loop` for a
/// range-edit write-back lives on the model, not here, so this type stays pure.
///
/// The cycle mirrors a practice player's A-B-repeat button:
///
///     idle ──tap──▶ armed(A) ──tap──▶ set(A↔B) ──tap──▶ idle ──▶ …
///
/// First tap drops **A** at the playhead; the second closes the span to **A↔B**
/// (ordered, widened to `minLoopWidth`); a third clears it. The closed span loops
/// ephemerally until promoted to a saved loop or cleared.
enum ABSpan: Equatable {
    /// Nothing set.
    case idle
    /// A placed at this song fraction, awaiting B (the forming state).
    case armed(Double)
    /// A closed span looping `start…end`. Always ordered (`start < end`).
    case set(start: Double, end: Double)

    /// The play-along set control was tapped while the playhead sits at
    /// `playhead` (a song fraction). Advances the three-state cycle: drop A, close
    /// to a span (ordered + widened via `WaveformGesture.loopBounds`), or clear.
    func tappingPlayhead(_ playhead: Double) -> ABSpan {
        switch self {
        case .idle:
            return .armed(playhead)
        case .armed(let pointA):
            return Self.closed(from: pointA, to: playhead)
        case .set:
            return .idle
        }
    }

    /// Close a span from two points — A at `anchor`, B at `current` — ordering them
    /// and widening to `minLoopWidth` if they landed too close (via
    /// `WaveformGesture.loopBounds`). The shared exit for both set gestures: the
    /// second play-along tap and a released spatial hold-drag.
    static func closed(from anchor: Double, to current: Double) -> ABSpan {
        let bounds = WaveformGesture.loopBounds(anchor, current)
        return .set(start: bounds.start, end: bounds.end)
    }

    /// The pending **A** while forming (`.armed`), else `nil` — for rendering the
    /// awaiting-B cue on the waveform.
    var armedPoint: Double? {
        if case .armed(let pointA) = self { return pointA }
        return nil
    }

    /// The closed span's bounds (`.set`), else `nil` — drives the engine loop region
    /// and the draggable A/B handles.
    var bounds: (start: Double, end: Double)? {
        if case .set(let start, let end) = self { return (start, end) }
        return nil
    }

    /// True once a span is closed and looping — the point at which "Save as loop"
    /// and the adjustable handles become available.
    var isSet: Bool { bounds != nil }
}
