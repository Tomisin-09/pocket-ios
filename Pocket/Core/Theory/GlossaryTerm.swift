import Foundation

/// One entry in the Toolkit **Glossary** (ADR 0096 Slice 1) — a term and a short, plain-language
/// definition, grouped by an area. Static in-house reference content (ADR 0065 T8): no audio, no state,
/// no dependencies, which is exactly why the glossary is a Slice-1 anchor.
///
/// Pure value type with no SwiftUI/SwiftData import, so the catalog and the search filter are
/// unit-tested. Definitions state *objective identity* only (what a term means) — never a judgement of
/// the player (ADR 0070): a glossary informs, it doesn't grade.
struct GlossaryTerm: Identifiable, Equatable {
    /// The area a term belongs to — drives the grouped sections in `GlossaryView`. Declaration order is
    /// the display order.
    enum Area: String, CaseIterable, Identifiable {
        case chords = "Chords"
        case scales = "Scales & modes"
        case intervals = "Intervals & pitch"
        case technique = "Technique"
        case general = "General"

        var id: String { rawValue }
    }

    let term: String
    let definition: String
    let area: Area

    /// Stable identity for `ForEach` — terms are unique by name across the catalog.
    var id: String { term }

    /// Case- and diacritic-insensitive match of a search query against the term **or** its definition,
    /// so "tritone" and "flat five" both surface the tritone entry. An empty/whitespace query matches
    /// everything (the unfiltered list). Pure, so `GlossaryView`'s filtering is unit-tested.
    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return term.range(of: trimmed, options: options) != nil
            || definition.range(of: trimmed, options: options) != nil
    }
}

extension GlossaryTerm {
    /// The full glossary catalog — in-house reference terms a player meets across Pocket's chord/scale
    /// tools. Kept alphabetical within each area for a scannable list.
    static let all: [GlossaryTerm] = [
        // MARK: Chords
        .init(term: "Add9",
              definition: "A major triad with the 9th (the 2nd, an octave up) added, but no 7th — e.g. "
                + "Cadd9. Brighter and more open than a full C9.",
              area: .chords),
        .init(term: "Arpeggio",
              definition: "The notes of a chord played one at a time rather than strummed together.",
              area: .chords),
        .init(term: "Augmented",
              definition: "A triad with a raised 5th (root, major 3rd, sharp 5th) — restless and "
                + "unresolved. Written “+” or “aug”, e.g. C+.",
              area: .chords),
        .init(term: "Barre chord",
              definition: "A movable shape where one finger presses several strings across a single "
                + "fret, letting you slide the same voicing up the neck to change key.",
              area: .chords),
        .init(term: "Diminished",
              definition: "A triad with a lowered 5th (root, minor 3rd, flat 5th) — tense and unstable. "
                + "Written “dim” or “°”, e.g. B°.",
              area: .chords),
        .init(term: "Extension",
              definition: "A chord tone stacked beyond the 7th — the 9th, 11th or 13th — that adds "
                + "colour without changing the chord's basic quality.",
              area: .chords),
        .init(term: "Inversion",
              definition: "A chord voiced with a note other than the root in the bass — e.g. C/E has the "
                + "3rd on the bottom.",
              area: .chords),
        .init(term: "Open chord",
              definition: "A chord that uses one or more open (unfretted) strings, usually near the nut "
                + "— the first shapes most players learn.",
              area: .chords),
        .init(term: "Power chord",
              definition: "Just the root and 5th (no 3rd), so it is neither major nor minor. Written "
                + "with a “5”, e.g. E5.",
              area: .chords),
        .init(term: "Seventh chord",
              definition: "A triad with a 7th added — dominant 7 (♭7), major 7 (♮7) or minor 7 (minor "
                + "triad plus ♭7) — richer and more directional than a plain triad.",
              area: .chords),
        .init(term: "Shell voicing",
              definition: "A stripped-back chord keeping only the root, 3rd and 7th — the notes that "
                + "define its quality — and leaving out the 5th.",
              area: .chords),
        .init(term: "Slash chord",
              definition: "A chord written “chord/bass” (e.g. C/G) telling you to put a specific note in "
                + "the bass — often an inversion.",
              area: .chords),
        .init(term: "Sus2 / Sus4",
              definition: "A suspended chord that replaces the 3rd with the 2nd (sus2) or 4th (sus4), "
                + "leaving it unresolved between major and minor.",
              area: .chords),
        .init(term: "Triad",
              definition: "A three-note chord: a root, a 3rd, and a 5th. Major, minor, diminished and "
                + "augmented are the four triad qualities.",
              area: .chords),
        .init(term: "Voicing",
              definition: "One specific arrangement of a chord's notes on the fretboard — which strings, "
                + "frets and octaves. The same chord has many voicings.",
              area: .chords),

        // MARK: Scales & modes
        .init(term: "Bebop scale",
              definition: "A seven-note scale (major or dominant) with one chromatic passing tone added, "
                + "so chord tones land on the beat in an eight-note line.",
              area: .scales),
        .init(term: "Blue note",
              definition: "The flattened 5th added to the minor pentatonic to make the blues scale — the "
                + "sliding, expressive note of blues and rock.",
              area: .scales),
        .init(term: "CAGED",
              definition: "A system that maps five open-chord shapes (C, A, G, E, D) up the neck, so one "
                + "scale or chord can be played in five linked positions.",
              area: .scales),
        .init(term: "Chromatic",
              definition: "Moving by semitones — using notes from outside the key — rather than staying "
                + "within a single scale.",
              area: .scales),
        .init(term: "Diatonic",
              definition: "Belonging to a single key's seven-note scale, with no notes borrowed from "
                + "outside it.",
              area: .scales),
        .init(term: "Diminished scale",
              definition: "An eight-note symmetric scale that alternates whole and half steps and "
                + "repeats every minor 3rd — used over diminished and dominant chords.",
              area: .scales),
        .init(term: "Mode",
              definition: "A scale built by starting a parent scale on a different degree — e.g. Dorian "
                + "is the major scale started on its 2nd — each with its own colour.",
              area: .scales),
        .init(term: "Pentatonic",
              definition: "A five-note scale. The minor and major pentatonics are the workhorse shapes "
                + "for guitar soloing.",
              area: .scales),
        .init(term: "Relative minor / major",
              definition: "A major and minor key that share the same notes (e.g. C major and A minor). "
                + "The minor starts on the major's 6th degree.",
              area: .scales),
        .init(term: "Root",
              definition: "The note a chord or scale is built on and named after — the C in a C chord or "
                + "C major scale.",
              area: .scales),
        .init(term: "Scale degree",
              definition: "A note's numbered position in a scale — 1 is the root, 5 the fifth — so "
                + "shapes and patterns can be described by number in any key.",
              area: .scales),
        .init(term: "Three notes per string",
              definition: "A scale fingering that places exactly three notes on each string, giving an "
                + "even, fast pattern that spans the neck.",
              area: .scales),
        .init(term: "Whole-tone scale",
              definition: "A six-note symmetric scale built entirely of whole steps, so it has no "
                + "leading tone — dreamlike and unresolved.",
              area: .scales),

        // MARK: Intervals & pitch
        .init(term: "Enharmonic",
              definition: "Two names for the same pitch — e.g. F♯ and G♭ — chosen to fit the key or "
                + "chord being spelled.",
              area: .intervals),
        .init(term: "Fifth (perfect)",
              definition: "The interval seven semitones above the root — the most consonant interval "
                + "after the octave, and the “5” in a power chord.",
              area: .intervals),
        .init(term: "Interval",
              definition: "The distance in pitch between two notes, named by how many scale steps and "
                + "the quality — e.g. major 3rd, perfect 5th.",
              area: .intervals),
        .init(term: "Octave",
              definition: "The interval between a note and the next note of the same name — double the "
                + "frequency, twelve semitones apart.",
              area: .intervals),
        .init(term: "Semitone (half step)",
              definition: "The smallest interval in Western music — one fret on the guitar. Twelve "
                + "semitones make an octave.",
              area: .intervals),
        .init(term: "Third",
              definition: "The interval that colours a chord major (four semitones) or minor (three "
                + "semitones) — the note a power chord deliberately leaves out.",
              area: .intervals),
        .init(term: "Tone (whole step)",
              definition: "Two semitones — two frets on the guitar.",
              area: .intervals),
        .init(term: "Tritone",
              definition: "Three whole tones — an augmented 4th / diminished 5th (the “flat five”). Six "
                + "semitones; the most dissonant interval in the octave.",
              area: .intervals),

        // MARK: Technique
        .init(term: "Alternate picking",
              definition: "Strict down-up-down-up picking, alternating stroke direction on every note "
                + "for speed and evenness.",
              area: .technique),
        .init(term: "Bend",
              definition: "Pushing or pulling a string across the fret to raise its pitch, gliding up to "
                + "the target note.",
              area: .technique),
        .init(term: "Downstroke / upstroke",
              definition: "A strum or pick toward the floor (down) or ceiling (up); alternating them "
                + "drives most strumming patterns.",
              area: .technique),
        .init(term: "Hammer-on / pull-off",
              definition: "Sounding a note by tapping a finger onto the fret (hammer-on) or pulling it "
                + "off to a lower note (pull-off) instead of picking.",
              area: .technique),
        .init(term: "Legato",
              definition: "Smoothly connected notes, often played with hammer-ons and pull-offs rather "
                + "than picking each one.",
              area: .technique),
        .init(term: "Palm mute",
              definition: "Resting the picking-hand palm lightly on the strings near the bridge to "
                + "dampen and shorten the notes.",
              area: .technique),
        .init(term: "Slide",
              definition: "Moving a fretting finger along a string from one fret to another without "
                + "re-picking, so the pitch glides.",
              area: .technique),
        .init(term: "Vibrato",
              definition: "A small, repeated bend that wavers a note's pitch to add warmth and sustain.",
              area: .technique),

        // MARK: General
        .init(term: "Bar (measure)",
              definition: "One group of beats set by the time signature — the repeating unit music is "
                + "counted in.",
              area: .general),
        .init(term: "Capo",
              definition: "A clamp across a fret that raises the pitch of all strings, letting open-chord "
                + "shapes play in a higher key.",
              area: .general),
        .init(term: "Downbeat",
              definition: "The first, strongest beat of a bar — the “1” you count a pattern from.",
              area: .general),
        .init(term: "Key",
              definition: "The tonal home of a piece — the scale and root its melody and chords are "
                + "built around, like the key of G major.",
              area: .general),
        .init(term: "Standard tuning",
              definition: "The default guitar tuning, from the lowest string to the highest: E A D G B E.",
              area: .general),
        .init(term: "Syncopation",
              definition: "Accenting off-beats — the “and” between beats — so the rhythm pushes against "
                + "the steady pulse.",
              area: .general),
        .init(term: "Tempo",
              definition: "How fast the music goes, measured in beats per minute (BPM).",
              area: .general),
        .init(term: "Time signature",
              definition: "Two stacked numbers showing how many beats are in a bar and which note value "
                + "gets the beat — e.g. 4/4.",
              area: .general),
        .init(term: "Transpose",
              definition: "Move a whole piece, scale or chord shape up or down by a fixed interval into "
                + "a different key.",
              area: .general)
    ]

    /// The catalog filtered by a search query, preserving catalog order. Empty query ⇒ the full list.
    static func matching(_ query: String) -> [GlossaryTerm] {
        all.filter { $0.matches(query) }
    }
}
