import SwiftUI

// MARK: - Per-template content sections (split from ConfigureExerciseForm for the 400-line cap)

extension ConfigureExerciseForm {
    /// A compact, read-only reminder of the chosen template — it lives at the **bottom** of the
    /// form (the important inputs are name/pattern/tempo up top) and stays a single row.
    var templateSection: some View {
        Section {
            HStack {
                Text("Template").foregroundStyle(PocketColor.textPrimary)
                Spacer()
                Image(systemName: template.iconName)
                Text(template.displayName).font(.futura(.subheadline, weight: .semibold))
            }
            .foregroundStyle(PocketColor.practice)
        } footer: {
            Text("Set for this drill and fixed after creation.")
        }
    }

    /// The **Guitar / Bass** control (ADR 0116) — a per-exercise axis fixed at creation, seeded from the
    /// profile's preferred instrument. Placed above the content editor so the generated preview below
    /// already reflects the chosen neck.
    var instrumentSection: some View {
        Section {
            Picker("Instrument", selection: $instrument) {
                ForEach(Instrument.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Instrument")
        } footer: {
            Text("Sets the neck this drill is drawn and generated for. Fixed after creation.")
        }
    }

    var strumSection: some View {
        Section {
            StrumPatternEditor(beatsPerBar: signature.beats, pattern: $strum)
                .listRowBackground(Color.clear)
        } header: {
            Text("Strum pattern")
        } footer: {
            Text("Tap the slots to build the pattern — it plays over the click when you run the "
                 + "drill. You can edit it later too.")
        }
    }

    /// The run families' authoring surface — a **generate-or-draw** split (ADR 0107): declare the run
    /// with `FretboardRunEditor`, or hand-draw it on the `FretboardDrillEditor` canvas with its scale
    /// guide. Draw mode emits a `.custom` drill; generate mode the declared run.
    var runSection: some View {
        Section {
            Picker("How to author", selection: $runMode) {
                Text("Generate").tag(AuthoringMode.generate)
                Text("Draw your own").tag(AuthoringMode.draw)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            switch runMode {
            case .generate:
                FretboardRunEditor(run: $run, instrument: instrument)
                    .listRowBackground(Color.clear)
            case .draw:
                FretboardDrillEditor(beatsPerBar: signature.beats, drill: $customDrill,
                                     referenceEnabled: true)
                    .listRowBackground(Color.clear)
            }
        } header: {
            Text("Fretboard run")
        } footer: {
            Text(runMode == .generate
                 ? "Declare the run's shape — finger pattern, where it sits, how far it travels — and "
                    + "it walks the board over the click. You can edit it later too."
                 : "Draw the run yourself — tap the notes onto the board up the neck. Turn on a Guide "
                    + "to ghost a scale's notes to trace. You can edit it later too.")
        }
    }

    /// The Scales template's authoring surface — the same generate-or-draw split: the `ScaleRunEditor`
    /// box picker, or the tap-to-place canvas with its scale guide (whole-tone / diminished escape
    /// hatch, ADR 0107).
    var scaleSection: some View {
        Section {
            Picker("How to author", selection: $scaleMode) {
                Text("Generate").tag(AuthoringMode.generate)
                Text("Draw your own").tag(AuthoringMode.draw)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            switch scaleMode {
            case .generate:
                ScaleRunEditor(run: $scale, instrument: instrument)
                    .listRowBackground(Color.clear)
            case .draw:
                FretboardDrillEditor(beatsPerBar: signature.beats, drill: $customDrill,
                                     referenceEnabled: true)
                    .listRowBackground(Color.clear)
            }
        } header: {
            Text("Scale run")
        } footer: {
            Text(scaleMode == .generate
                 ? "Pick a scale and its root — the box walks the neck over the click. You can change "
                    + "it later too."
                 : "Draw the scale yourself. Turn on a Guide to ghost a scale's notes — including "
                    + "whole-tone and diminished — then tap them up the neck.")
        }
    }

    /// The Arpeggios template's authoring surface — the same generate-or-draw split (ADR 0107): the
    /// `ArpeggioRunEditor` chord-tone box picker, or the tap-to-place canvas with its scale guide for
    /// any hand-shaped arpeggio the box generator can't declare.
    var arpeggioSection: some View {
        Section {
            Picker("How to author", selection: $arpeggioMode) {
                Text("Generate").tag(AuthoringMode.generate)
                Text("Draw your own").tag(AuthoringMode.draw)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            switch arpeggioMode {
            case .generate:
                ArpeggioRunEditor(run: $arpeggio, instrument: instrument)
                    .listRowBackground(Color.clear)
            case .draw:
                FretboardDrillEditor(beatsPerBar: signature.beats, drill: $customDrill,
                                     referenceEnabled: true, guideCatalog: ScaleReference.arpeggios)
                    .listRowBackground(Color.clear)
            }
        } header: {
            Text("Arpeggio run")
        } footer: {
            Text(arpeggioMode == .generate
                 ? "Pick a quality and its root — the chord-tone box walks the neck over the click. "
                    + "You can change it later too."
                 : "Draw the arpeggio yourself — tap the chord tones onto the board. Turn on a Guide "
                    + "to ghost an arpeggio's chord tones to trace. You can edit it later too.")
        }
    }

    var chordsSection: some View {
        Section {
            ChordProgressionEditor(progression: $chords)
                .listRowBackground(Color.clear)
        } header: {
            Text("Chord progression")
        } footer: {
            Text("Build the progression and how long each chord is held — it changes on the beat "
                 + "over the click. You can edit it later too.")
        }
    }

    var strumChordsSection: some View {
        Section {
            // Both editors live in ONE row (a single VStack) with an internal hairline between them.
            // Keeping them as separate Section rows put the `Divider` in its own ~44pt-tall List row,
            // bracketed by the Form's row separators — the "phantom empty box" of device feedback
            // (2026-07-23). One row with an in-VStack divider removes the extra row entirely.
            VStack(spacing: 14) {
                StrumPatternEditor(beatsPerBar: signature.beats,
                                   pattern: $strumChords.strumPattern)
                Divider()
                ChordProgressionEditor(progression: $strumChords.chordProgression)
            }
            .listRowBackground(Color.clear)
        } header: {
            Text("Strum & chords")
        } footer: {
            Text("The strum lane plays its own repeating groove while the chords change under it — "
                 + "they aren't locked together, so pick a groove length that divides evenly into "
                 + "each chord's hold if you want them to land together. You can edit both later too.")
        }
    }

    var fretboardSection: some View {
        Section {
            FretboardDrillEditor(beatsPerBar: signature.beats, drill: $customDrill)
                .listRowBackground(Color.clear)
        } header: {
            Text("Fretboard drill")
        } footer: {
            Text("Build the note sequence on the board — it walks the fretboard over the click when "
                 + "you run the drill. You can edit it later too.")
        }
    }
}
