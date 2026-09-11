import SwiftData
import SwiftUI

/// The parts of goal authoring **both tiers share** (ADR 0171 D5): pick a starting template, trim
/// its skills, and — for a repertoire goal — name the target song. Extracted from `GoalEditorView`
/// when the long-term tier arrived, so the two editors differ only in the fields that genuinely
/// diverge (a `Goal` is weighted, a `LongTermGoal` is ranked by list position) rather than in a
/// second copy of the same three sections.
///
/// The tiers split by **scope of intent, not vocabulary**, which is why `GoalTemplateLibrary` seeds
/// either one unchanged.

/// "Start from a goal" — the template picker a new goal of either tier begins on.
struct GoalTemplatePicker: View {
    /// Called with the picked template; the caller seeds its own fields from it.
    let onPick: (GoalTemplate) -> Void
    /// Called for **Something else** — go straight to the form with nothing seeded, and pick from
    /// the full catalogue instead.
    let onStartBlank: () -> Void

    var body: some View {
        List {
            Section {
                ForEach(GoalTemplateLibrary.all) { candidate in
                    Button { onPick(candidate) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: candidate.iconName)
                                .font(.futura(.title3))
                                .foregroundStyle(PocketColor.practice)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.title)
                                    .font(.futura(.body))
                                    .foregroundStyle(PocketColor.textPrimary)
                                Text(candidate.blurb)
                                    .font(.futura(.caption))
                                    .foregroundStyle(PocketColor.textSecondary)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.futura(.caption))
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(PocketColor.background)
                }
            } header: {
                Text("Start from a goal")
            } footer: {
                Text("Pick a starting point, then trim the skills to what you want to focus on.")
                    .font(.futura(.caption))
            }

            // The ten templates cover what the planner can actually resolve, but they are a
            // *starting* vocabulary, not the limit of one. This skips the seed and opens the full
            // catalogue instead.
            //
            // It is **not** the blank-goal option ADR 0015 Decision 7 ruled out. That ban was on a
            // goal with no skills — "an empty one schedules nothing" — and the thing that actually
            // enforces it is the editor's Save gate, which stays disabled until at least one skill
            // is kept. Nor does it reintroduce free text: the catalogue is the same fixed taxonomy
            // a template seeds from. What it removes is only the obligation to start from someone
            // else's phrasing of the goal.
            Section {
                Button(action: onStartBlank) {
                    HStack(spacing: 14) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.futura(.title3))
                            .foregroundStyle(PocketColor.practice)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Something else")
                                .font(.futura(.body))
                                .foregroundStyle(PocketColor.textPrimary)
                            Text("Name it yourself and pick the skills from the full catalogue.")
                                .font(.futura(.caption))
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(PocketColor.background)
            }
        }
    }
}

/// The trimmable skill list — every offered skill as a toggle row, plus a way into the full catalog.
/// Each row also says what the skill actually pulls from the player's library, and offers a fix
/// when a kept skill pulls nothing (ADR 0216 D4).
struct GoalSkillsSection: View {
    @Binding var offeredSkillIDs: [String]
    @Binding var keptSkillIDs: Set<String>
    @Binding var showingSkillPicker: Bool
    /// What each offered skill reaches, keyed by skill id — from `goalSkillReach`, so both editors
    /// measure the same way.
    var reach: [String: SkillReach] = [:]
    /// Called with the skill and the fix the player tapped under it, when it reaches nothing.
    var onFix: (String, SkillAssociation.Fix) -> Void = { _, _ in }
    /// The skills the player made (ADR 0216 D7), so a row names one by its name, never its id.
    @Query private var customSkills: [CustomSkill]

    var body: some View {
        let vocabulary = SkillVocabulary(customSkills)
        return Section {
            ForEach(offeredSkillIDs, id: \.self) { skillID in
                GoalSkillRow(skillID: skillID, name: vocabulary.name(skillID),
                             explanation: vocabulary.explanation(skillID),
                             isKept: keptSkillIDs.contains(skillID),
                             reach: reach[skillID], onToggle: { toggle(skillID) },
                             onFix: { onFix(skillID, $0) })
                    .listRowBackground(PocketColor.background)
            }
            Button { showingSkillPicker = true } label: {
                Label("Add skills", systemImage: "plus.circle")
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.practice)
            }
            .listRowBackground(PocketColor.background)
        } header: {
            Text("Skills")
        } footer: {
            Text(keptSkillIDs.isEmpty
                 ? "Keep at least one skill for this goal to schedule anything."
                 : "Tap to include or drop a skill, or add more from the full catalog.")
                .font(.futura(.caption))
        }
    }

    private func toggle(_ skillID: String) {
        if keptSkillIDs.contains(skillID) { keptSkillIDs.remove(skillID) } else { keptSkillIDs.insert(skillID) }
        haptic(.light)
    }
}

/// The Path-B target song, shown only while a kept skill routes through repertoire.
struct GoalTargetSongSection: View {
    let songs: [Song]
    @Binding var targetSong: Song?

    var body: some View {
        Section {
            if songs.isEmpty {
                Text("Add a song to your library to target it here.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                // A **pushed searchable list**, not a popup picker (v2 close-out N3). The choices
                // here are the player's own library, so the list is unbounded — a menu works on the
                // day it holds four songs and is unusable on the day it holds forty. Searching the
                // artist line matters as much as the title: which one you remember is a coin toss.
                NavigationLink {
                    SearchablePickerList(
                        title: "Target song",
                        items: songs.map {
                            PickerItem(value: $0, title: $0.title.isEmpty ? "Untitled" : $0.title,
                                       context: $0.artist)
                        },
                        clearLabel: "None", selection: $targetSong)
                } label: {
                    LabeledContent("Song") {
                        Text(targetSong.map { $0.title.isEmpty ? "Untitled" : $0.title } ?? "None")
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    .font(.futura(.body))
                }
                .tint(PocketColor.practice)
                .listRowBackground(PocketColor.background)
            }
        } header: {
            Text("Target song")
        } footer: {
            Text("Learning a song schedules its loops and a play-through. Pick one to include it.")
                .font(.futura(.caption))
        }
    }
}

/// What each offered skill reaches in the player's library (ADR 0216 D4), keyed by skill id — shared
/// by both editors so the two can't measure differently. The target song is passed only while a
/// kept skill needs one, matching what `save()` would store, so the line never counts a song the
/// goal won't keep.
@MainActor
func goalSkillReach(_ skillIDs: [String], targetSong: Song?, exercises: [Exercise], loops: [Loop],
                    songs: [Song]) -> [String: SkillReach] {
    let library = PracticePlanner.library(exercises: exercises, loops: loops, songs: songs)
    let songUID = targetSong.map { PlannerID.uid(from: $0.sourceID) }
    let reach = GoalReach.reach(skillIDs: skillIDs, targetSongUID: songUID, library: library)
    return Dictionary(reach.map { ($0.skillID, $0) }, uniquingKeysWith: { first, _ in first })
}

/// Whether any kept skill routes via the target song (Path B) — shared by both editors so the two
/// can't disagree about when the song picker is relevant.
func goalNeedsTargetSong(_ keptSkillIDs: Set<String>) -> Bool {
    keptSkillIDs.contains { TechniqueTaxonomy.mode($0)?.isRepertoire == true }
}
