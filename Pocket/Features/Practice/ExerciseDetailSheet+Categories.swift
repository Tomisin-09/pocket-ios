import SwiftUI

/// The exercise ⓘ sheet's rows (ADR 0258): **Progress**, **Songs**, **References**, **Folders** and
/// **Feel & skills**, each saying what is behind it so the common visit ends with the description.
/// Each pushes a screen inside the sheet's `NavigationStack` (`ExerciseDetailScreens.swift`) that raises
/// its own presentations.
extension ExerciseDetailSheet {

    var categoriesSection: some View {
        Section {
            progressRow
            songsRow
            referencesRow
            foldersRow
            feelRow
        }
    }

    /// The rating is the sheet's local copy, kept on Done, so Progress gets a binding to it — and the
    /// row shows the dots from that copy, so a rating changed there shows here before Done.
    private var progressRow: some View {
        NavigationLink {
            ExerciseProgressScreen(mastery: $mastery,
                                   lastPracticed: exercise.lastPracticed,
                                   reading: exercise.masteryReading,
                                   trajectory: TempoTrajectory.reading(for: exercise.uid, in: sessionRecords),
                                   runCount: TempoTrajectory.runCount(for: exercise.uid, in: sessionRecords))
        } label: {
            HubRow(icon: "chart.line.uptrend.xyaxis", title: "Progress") {
                if let mastery {
                    MasteryDots(filled: mastery, size: 8)
                } else {
                    Text("Unrated").foregroundStyle(PocketColor.textSecondary)
                }
            }
        }
    }

    /// A song opens in the player only where the host gave it somewhere to go (ADR 0172), and that tap
    /// closes the sheet — so the description and rating, held for Done, are committed first rather than
    /// silently dropped by a navigation tap.
    private var songsRow: some View {
        NavigationLink {
            ExerciseSongsScreen(exercise: exercise, onOpenSong: onOpenSong.map { open in
                { song in
                    commitNotes()
                    commitMastery()
                    open(song)
                }
            })
        } label: {
            HubRow(icon: "music.note", title: "Songs", value: songsValue)
        }
    }

    private var referencesRow: some View {
        NavigationLink { ReferencesScreen(owner: exercise, accent: PocketColor.practice) } label: {
            HubRow(icon: "link", title: "References", value: exercise.referencesRowValue)
        }
    }

    private var foldersRow: some View {
        NavigationLink { ExerciseFoldersScreen(exercise: exercise) } label: {
            HubRow(icon: "folder", title: "Folders", value: foldersValue)
        }
    }

    /// The template and the meter, the two facts a glance wants; Works on is inside.
    private var feelRow: some View {
        NavigationLink { ExerciseFeelScreen(exercise: exercise) } label: {
            HubRow(icon: exercise.template.iconName, title: "Feel & skills", value: feelValue)
        }
    }

    /// The songs' titles, not a count of them: a name says which.
    private var songsValue: String {
        let titles = exercise.linkedSongs
            .map { $0.title.isEmpty ? "Untitled song" : $0.title }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return titles.isEmpty ? "None" : titles.joined(separator: ", ")
    }

    private var foldersValue: String {
        exercise.folders.isEmpty ? "None" : exercise.folders.map(FolderPath.leaf).joined(separator: ", ")
    }

    /// `Warm-up · 4/4`. A freeform drill has no meter of its own to state (ADR 0136), so it says its kind.
    private var feelValue: String {
        isFreeform
            ? exercise.template.displayName
            : "\(exercise.template.displayName) · \(exercise.timeSignatureLabel)"
    }
}
