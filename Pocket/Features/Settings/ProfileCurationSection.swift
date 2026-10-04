import SwiftData
import SwiftUI

/// The **"Your sound"** editor (ADR 0113, Slice 2): the four curation fields the first-launch intake
/// collects, editable any time. A top-level Settings section until ADR 0162 folded it into
/// **Settings ▸ You** beneath the artist name — the two were separate sections answering the same
/// question. Reads the singleton `Profile` passed in and writes every change
/// straight through `Profile.setCuration`, creating the row on first use — a player who skipped the
/// intake can still declare intent here, and one who ran it can revise it.
///
/// Optional by design: each picker offers a "Not set" choice and genres can be empty, matching the
/// intake's skippable nature. Nothing here is PII — musical preferences only.
struct ProfileCurationSection: View {
    @Environment(\.modelContext) private var context
    /// The singleton profile (or `nil` before any row exists). Its properties seed the drafts.
    let profile: Profile?

    @State private var experience: ArtistExperience?
    @State private var genres: Set<MusicGenre> = []
    @State private var dream: MusicalDream?
    @State private var minutes: PracticeMinutes?
    /// What you play (ADR 0248, widening ADR 0116's Guitar/Bass). Unlike the four curation fields this
    /// has **no "Not set"**: a profile that never answered reads as the neck it has, which falls back to
    /// guitar (`Profile.playsOrNeck`), so an unanswered question and an answer of "guitar" are the same
    /// state. Written through its own `setPlays`, not `setCuration`: Guitar or Bass also sets what a fresh
    /// drill *is* drawn on, and changing it adds or removes nothing in the library.
    @State private var plays: PlayedInstrument = .guitar
    @State private var seeded = false

    var body: some View {
        Section {
            Picker("You play", selection: $plays) {
                ForEach(PlayedInstrument.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }

            Picker("Experience", selection: $experience) {
                Text("Not set").tag(ArtistExperience?.none)
                ForEach(ArtistExperience.allCases) { option in
                    Text(option.displayName(for: plays)).tag(ArtistExperience?.some(option))
                }
            }

            NavigationLink {
                GenreMultiSelectView(selection: $genres)
                    .onChange(of: genres) { commit() }
            } label: {
                HStack {
                    Text("Genres")
                    Spacer()
                    Text(genreSummary)
                        .foregroundStyle(PocketColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Picker("Dream", selection: $dream) {
                Text("Not set").tag(MusicalDream?.none)
                ForEach(MusicalDream.allCases) { option in
                    Text(option.displayName).tag(MusicalDream?.some(option))
                }
            }

            Picker("Time most days", selection: $minutes) {
                Text("Not set").tag(PracticeMinutes?.none)
                ForEach(PracticeMinutes.allCases) { option in
                    Text(option.displayName).tag(PracticeMinutes?.some(option))
                }
            }
        } header: {
            Text("Your sound")
        } footer: {
            Text("Shapes what the app suggests — starting tempo, session length, and what surfaces "
                 + "first. Optional, and it stays on this device. New exercises on the neck open on "
                 + "your guitar or bass; each drill keeps its own, so changing this never rewrites one "
                 + "you already made.")
        }
        .onAppear(perform: seedFromProfile)
        .onChange(of: experience) { commit() }
        .onChange(of: dream) { commit() }
        .onChange(of: minutes) { commit() }
        .onChange(of: plays) { commitPlays() }
    }

    /// A one-line summary of the chosen genres for the row's trailing value.
    private var genreSummary: String {
        guard !genres.isEmpty else { return "Any" }
        return MusicGenre.allCases
            .filter { genres.contains($0) }
            .map(\.displayName)
            .joined(separator: ", ")
    }

    /// Seed the drafts from the profile once, so re-appearing (e.g. after editing genres) doesn't
    /// clobber in-flight edits.
    private func seedFromProfile() {
        guard !seeded else { return }
        experience = profile?.experience
        genres = Set(profile?.genres ?? [])
        dream = profile?.dream
        minutes = profile?.minutesPerDay
        plays = profile?.playsOrNeck ?? .guitar
        seeded = true
    }

    /// Persist the current drafts (skipped fields stay unset). Cheap; the whole profile is one row.
    private func commit() {
        guard seeded else { return } // ignore the initial programmatic seeding
        Profile.setCuration(experience: experience, genres: Array(genres),
                            dream: dream, minutesPerDay: minutes, in: context)
    }

    /// Persist what you play on its own — `setCuration` overwrites the four curation fields as a
    /// set, so folding this into it would make an instrument change able to clear them.
    private func commitPlays() {
        guard seeded else { return }
        Profile.setPlays(plays, in: context)
    }
}

/// A native multi-select checklist for the genre field, pushed from the "Your sound" section.
struct GenreMultiSelectView: View {
    @Binding var selection: Set<MusicGenre>

    var body: some View {
        List {
            ForEach(MusicGenre.allCases) { genre in
                Button {
                    if selection.contains(genre) { selection.remove(genre) } else { selection.insert(genre) }
                    haptic(.light)
                } label: {
                    HStack {
                        Text(genre.displayName)
                            .foregroundStyle(PocketColor.textPrimary)
                        Spacer()
                        if selection.contains(genre) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(PocketColor.practice)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(PocketColor.background)
                .accessibilityAddTraits(selection.contains(genre) ? .isSelected : [])
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Genres")
        .navigationBarTitleDisplayMode(.inline)
    }
}
