import SwiftData
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

    // MARK: - Linked songs (ADR 0111)

    /// The songs this drill is *for*, pickable **at creation** rather than only afterwards on
    /// `ExerciseDetailSheet` — the same edge, the same `LinkPickerSheet`, just staged in `pickedSongs`
    /// until Create attaches it.
    ///
    /// Hidden entirely when the library holds no songs: with nothing to pick, the row would open an
    /// empty picker and only lengthen an already-long form. It reappears by itself once a song is
    /// imported, and the link is always authorable later from the drill's detail sheet.
    @ViewBuilder
    var songsSection: some View {
        if !allSongs.isEmpty {
            Section {
                ForEach(pickedSongsByTitle, id: \.persistentModelID) { song in
                    HStack(spacing: 8) {
                        Text(song.title.isEmpty ? "Untitled song" : song.title)
                            .foregroundStyle(PocketColor.textPrimary)
                        if !song.artist.isEmpty {
                            Text(song.artist)
                                .font(.futura(.caption))
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                    }
                }
                .onDelete(perform: unpickSongs)
                Button { showingSongPicker = true } label: {
                    Label(pickedSongs.isEmpty ? "Link songs" : "Link more songs",
                          systemImage: "plus.circle")
                        .foregroundStyle(PocketColor.practice)
                }
            } header: {
                Text("Songs")
            } footer: {
                Text("Optional — the songs this drill is for. Links show on the song too, and seed a "
                     + "one-tap practice routine for it. You can change them later.")
            }
        }
    }

    var pickedSongsByTitle: [Song] {
        pickedSongs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func isPicked(_ song: Song) -> Bool {
        pickedSongs.contains { $0.persistentModelID == song.persistentModelID }
    }

    /// Toggle a song's link in the *staged* selection — no `save()` here, unlike the detail sheet's
    /// equivalent: nothing is persisted until Create.
    func togglePick(_ song: Song) {
        if let index = pickedSongs.firstIndex(where: { $0.persistentModelID == song.persistentModelID }) {
            pickedSongs.remove(at: index)
        } else {
            pickedSongs.append(song)
        }
    }

    func unpickSongs(at offsets: IndexSet) {
        let targets = offsets.map { pickedSongsByTitle[$0] }
        for song in targets {
            pickedSongs.removeAll { $0.persistentModelID == song.persistentModelID }
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
            ChordProgressionEditor(progression: $chords, instrument: instrument)
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
                ChordProgressionEditor(progression: $strumChords.chordProgression,
                                       instrument: instrument)
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
