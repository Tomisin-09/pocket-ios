import SwiftUI

// MARK: - How to play (per-template content editor, ADR 0065)

/// Split from `ExerciseShapeSheet.swift` for the 400-line cap. The state these read is internal for that
/// reason alone: nothing outside the sheet writes it.
extension ExerciseShapeSheet {

    /// The strumming template's authoring surface — the tap-to-edit `StrumPatternEditor` over the
    /// exercise's always-present pattern. No "remove" control: the template is immutable, so a
    /// strumming drill stays a strumming drill; you edit the pattern, you don't strip it.
    var strummingSection: some View {
        Section {
            StrumPatternEditor(beatsPerBar: exercise.beatsPerBar, pattern: $strum)
                .listRowBackground(Color.clear)
        } header: {
            Text("How to play — strumming")
        } footer: {
            Text("The arrow lane plays over the click while you run the drill. Slots loop every "
                 + "\(exercise.beatsPerBar) beats.")
        }
    }

    /// The warm-up family's authoring surface — a **generate-or-draw** split (ADR 0107): the generative
    /// `FretboardRunEditor` (generate), or the tap-to-place `FretboardDrillEditor` with its scale guide
    /// (draw your own), the escape hatch for any hand-shaped run the generator can't declare. Same
    /// immutability contract: the template stays a fretboard run; you edit its shape.
    var runSection: some View {
        Section {
            AuthoringModePicker(mode: $runMode)
                .listRowBackground(Color.clear)

            switch runMode {
            case .generate:
                FretboardRunEditor(run: $run, instrument: exercise.instrument, template: exercise.template)
                    .listRowBackground(Color.clear)
            case .draw:
                FretboardDrillEditor(beatsPerBar: exercise.beatsPerBar, drill: $customDrill,
                                     referenceEnabled: true, template: exercise.template)
                    .listRowBackground(Color.clear)
            }
        } header: {
            Text("How to play — run")
        } footer: {
            Text(runMode == .generate
                 ? "Declare the run's shape and it walks the board over the click while you run the "
                    + "drill."
                 : "Draw the run yourself — tap the notes onto the board. Turn on a Guide to ghost a "
                    + "scale's notes to trace.")
        }
    }

    /// The Scales template's authoring surface — a **generate-or-draw** split: the `ScaleRunEditor`
    /// box picker (generate), or the tap-to-place `FretboardDrillEditor` with its scale guide (draw your
    /// own), the escape hatch for scales the box generator can't place (whole-tone, diminished) and any
    /// hand-shaped run. Same immutability contract: the template stays a fretboard scales drill.
    var scaleSection: some View {
        Section {
            AuthoringModePicker(mode: $scaleMode)
                .listRowBackground(Color.clear)

            switch scaleMode {
            case .generate:
                ScaleRunEditor(run: $scale, instrument: exercise.instrument)
                    .listRowBackground(Color.clear)
            case .draw:
                FretboardDrillEditor(beatsPerBar: exercise.beatsPerBar, drill: $customDrill,
                                     referenceEnabled: true)
                    .listRowBackground(Color.clear)
            }
        } header: {
            Text("How to play — scale")
        } footer: {
            Text(scaleMode == .generate
                 ? "Pick a scale and its root; the box walks the neck over the click while you run "
                    + "the drill."
                 : "Draw the scale yourself. Turn on a Guide to ghost a scale's notes on the board — "
                    + "including whole-tone and diminished — then tap them up the neck.")
        }
    }

    /// The Arpeggios template's authoring surface — a **generate-or-draw** split (ADR 0107): the
    /// `ArpeggioRunEditor` chord-tone box picker (generate), or the tap-to-place `FretboardDrillEditor`
    /// with its scale guide (draw your own), the escape hatch for any hand-shaped arpeggio the box
    /// generator can't declare. Same immutability contract: the template stays fretboard.
    var arpeggioSection: some View {
        Section {
            AuthoringModePicker(mode: $arpeggioMode)
                .listRowBackground(Color.clear)

            switch arpeggioMode {
            case .generate:
                ArpeggioGenerateRows(shape: $arpeggioShape, box: $arpeggio, triads: $triads,
                                     instrument: exercise.instrument, beatsPerBar: exercise.beatsPerBar,
                                     carriesBoxKey: carriesBoxKey)
                    .listRowBackground(Color.clear)
            case .draw:
                FretboardDrillEditor(beatsPerBar: exercise.beatsPerBar, drill: $customDrill,
                                     referenceEnabled: true, guideCatalog: ScaleReference.arpeggios)
                    .listRowBackground(Color.clear)
            }
        } header: {
            Text("How to play — arpeggio")
        } footer: {
            Text(arpeggioFooter)
        }
    }

    private var arpeggioFooter: String {
        switch (arpeggioMode, generatedArpeggio.triadsValue != nil) {
        case (.draw, _):
            return "Draw the arpeggio yourself — tap the chord tones onto the board. Turn on a Guide "
                + "to ghost an arpeggio's chord tones to trace."
        case (.generate, true):
            return "Pick a key, three strings and the chords; each chord's shape walks the board over the "
                + "click while you run the drill."
        case (.generate, false):
            return "Pick a quality and its root; the chord-tone box walks the neck over the click "
                + "while you run the drill."
        }
    }

    /// The Chords template's authoring surface — the `ChordProgressionEditor`. Same immutability
    /// contract: the template stays chords; you edit the progression, not the type.
    var chordsSection: some View {
        Section {
            ChordProgressionEditor(progression: $chords, instrument: exercise.instrument,
                                   beatsPerBar: exercise.beatsPerBar)
                .listRowBackground(Color.clear)
        } header: {
            Text("How to play — chords")
        } footer: {
            Text("The chords change on the beat over the click while you run the drill. The "
                 + "progression loops.")
        }
    }

    /// The Strum & Chords template's authoring surface — the `StrumPatternEditor` and
    /// `ChordProgressionEditor` stacked, editing the two halves of the exercise's `StrumChordSheet`.
    /// Same immutability contract: the template stays strum-chords.
    var strumChordsSection: some View {
        Section {
            // One row with an in-VStack hairline — a standalone `Divider` row rendered as a phantom
            // empty box between the Form's row separators (device feedback 2026-07-23).
            VStack(spacing: 14) {
                StrumPatternEditor(beatsPerBar: exercise.beatsPerBar, pattern: $strumChords.strumPattern)
                Divider()
                ChordProgressionEditor(progression: $strumChords.chordProgression,
                                       instrument: exercise.instrument, beatsPerBar: exercise.beatsPerBar)
            }
            .listRowBackground(Color.clear)
        } header: {
            Text("How to play — strum & chords")
        } footer: {
            Text("The strum lane loops on its own while the chords change over the click — the two "
                 + "aren't locked together.")
        }
    }

    /// The custom-drill authoring surface — the tap-to-place `FretboardDrillEditor`. Same
    /// immutability contract: the template stays fretboard.
    var fretboardSection: some View {
        Section {
            FretboardDrillEditor(beatsPerBar: exercise.beatsPerBar, drill: $customDrill)
                .listRowBackground(Color.clear)
        } header: {
            Text("How to play — fretboard")
        } footer: {
            Text("The notes walk the board over the click while you run the drill. Slots loop every "
                 + "\(exercise.beatsPerBar) beats.")
        }
    }
}
