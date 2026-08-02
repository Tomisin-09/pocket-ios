import SwiftData
import SwiftUI

/// **Build today's session** — the V2 planner's front door (ADR 0046 re-homes ADRs 0014–0016;
/// Slice 3). Pick how long you have (`SessionLength`), keep a short list of **goals** that shape what
/// surfaces, then **Generate** — the front-half (`CandidateDeriver`) expands your active goals into a
/// ranked pool and the back-half (`SessionBuilder`) lays out a timed session, materialised into a
/// provisional `Routine` you review before Starting (nothing persists until you Save or Start it).
///
/// With **no active goals** this falls back to a goal-less **Quick session** (Slice 1): due-ranked
/// exercises alone — so the button always produces something to practise.
struct PlannerView: View {
    @Environment(\.modelContext) private var context
    @Query private var goals: [Goal]
    @Query private var exercises: [Exercise]
    @Query private var loops: [Loop]
    @Query private var songs: [Song]
    @Query private var routines: [Routine]
    /// The local profile (ADR 0113): its minutes-per-day seeds the initial session length (S2) and its
    /// genres + dream drive the goal-session emphasis mix (S3).
    @Query private var profiles: [Profile]
    /// The practice log (ADR 0117), read here for one thing only: **how recently each unit was
    /// practised** (ADR 0137). It is what gives a loop candidate a time axis — loops carry no stored
    /// `lastPracticed`, so without this every one of them ranks as never-practised.
    @Query private var practiceRuns: [PracticeRun]

    @State private var length: SessionLength = .default
    /// Whether this session is being built for practice **away from the instrument** (ADR 0139) —
    /// a constraint on the same planner, not a second one. Not persisted: it is a fact about *this
    /// afternoon*, not a preference, and a player who practised on a train yesterday should not find
    /// the planner still assuming it today.
    @State private var constraint: SessionConstraint = .none
    /// Seed the length from the profile only once, so revisiting the planner doesn't overwrite a
    /// duration the player just picked by hand.
    @State private var seededLength = false
    /// The goal being edited, presented as a sheet. Held as a `uid`-keyed `StableRef`, not the raw
    /// `Goal`: a goal added and edited in the same session has a temporary `persistentModelID` that
    /// flips on the first save, which would dismiss the editor mid-edit if the sheet were keyed on it
    /// (ADR 0090 / swiftdata-gotchas).
    @State private var editingGoal: StableRef<Goal>?
    @State private var addingGoal = false
    /// A freshly-generated session awaiting review — pushed as a provisional `RoutineDetailView`.
    @State private var draft: QuickSessionDraft?
    /// Shown when generation yields nothing runnable (no exercises, no resolvable target song).
    @State private var showingEmptyNotice = false

    /// The goals that actively shape a session (not marked met), newest first.
    private var activeGoals: [Goal] {
        goals.filter { !$0.isMet }.sorted { $0.dateAdded > $1.dateAdded }
    }

    private var metGoals: [Goal] {
        goals.filter(\.isMet).sorted { $0.dateAdded > $1.dateAdded }
    }

    var body: some View {
        List {
            durationSection
            situationSection
            goalsSection
            if !metGoals.isEmpty { metSection }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle("Today's session")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: seedLengthFromProfile)
        .safeAreaInset(edge: .bottom) { generateBar }
        .sheet(isPresented: $addingGoal) {
            GoalEditorView(existing: nil, songs: songs)
        }
        .sheet(item: $editingGoal) { ref in
            GoalEditorView(existing: ref.value, songs: songs)
        }
        .navigationDestination(item: $draft) { draft in
            RoutineDetailView(container: context.container,
                              generatedSession: draft.blocks, defaultName: draft.name,
                              targetMinutes: draft.targetMinutes)
        }
        .alert("Nothing to schedule yet", isPresented: $showingEmptyNotice) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(emptyNoticeMessage)
        }
    }

    // MARK: - Duration

    private var durationSection: some View {
        Section {
            Picker("How long?", selection: $length) {
                ForEach(SessionLength.allCases) { option in
                    // "~" because the preset is a count of blocks now, not a minute budget — the
                    // number is an estimate of the whole sitting (ADR 0129). Matches the grammar
                    // `CollectionSessionSheet` already uses for its Length tabs.
                    Text("\(option.displayName) · ~\(option.minutes)m").tag(option)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(PocketColor.background)
        } header: {
            Text("How long do you have?")
        }
    }

    // MARK: - Situation

    /// **Where you are, not what you own** (ADR 0139 O3). A toggle rather than a third segmented
    /// control: it is an occasional exception, and the ordinary case shouldn't have to be re-chosen
    /// every visit.
    private var situationSection: some View {
        Section {
            Toggle(isOn: Binding(get: { constraint == .offGuitar },
                                 set: { constraint = $0 ? .offGuitar : .none })) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(SessionConstraint.offGuitar.displayName)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(SessionConstraint.offGuitar.caption)
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            .tint(PocketColor.practice)
            .listRowBackground(PocketColor.background)
        }
    }

    // MARK: - Goals

    private var goalsSection: some View {
        Section {
            if activeGoals.isEmpty {
                Text("No goals yet — Generate builds a quick, due-based session from your exercises. "
                     + "Add a goal to steer what you practise.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(activeGoals) { goal in
                    goalRow(goal)
                }
            }
            Button { addingGoal = true; haptic(.light) } label: {
                Label("Add a goal", systemImage: "plus.circle.fill")
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.practice)
            }
            .listRowBackground(PocketColor.background)
        } header: {
            Text("Goals")
        }
    }

    private var metSection: some View {
        Section("Met") {
            ForEach(metGoals) { goal in
                Button { editingGoal = StableRef(value: goal); haptic(.light) } label: {
                    HStack {
                        Text(goal.title.isEmpty ? "Untitled goal" : goal.title)
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textSecondary)
                            .strikethrough()
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(PocketColor.background)
                .swipeActions(edge: .trailing) { deleteAction(goal) }
            }
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        Button { editingGoal = StableRef(value: goal); haptic(.light) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title.isEmpty ? "Untitled goal" : goal.title)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(subtitle(for: goal))
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.practice)
                }
                Spacer(minLength: 8)
                Text(GoalPriority.nearest(toWeight: goal.weight).label.uppercased())
                    .font(.futura(.caption2, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(PocketColor.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(PocketColor.background)
        .swipeActions(edge: .trailing) { deleteAction(goal) }
    }

    /// Trailing swipe → remove a goal outright from this screen — no need to open the editor just to
    /// delete. Deleting a `Goal` nullifies its optional `targetSong` link (default to-one rule), so no
    /// song is touched; a met goal is removable the same way.
    private func deleteAction(_ goal: Goal) -> some View {
        Button(role: .destructive) { deleteGoal(goal) } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func deleteGoal(_ goal: Goal) {
        context.delete(goal)
        haptic(.medium)
    }

    /// "3 skills · Little Wing" — the goal's shape at a glance; the target song appended when set.
    private func subtitle(for goal: Goal) -> String {
        let count = goal.skillIDs.count
        var parts = ["\(count) skill\(count == 1 ? "" : "s")"]
        if let song = goal.targetSong, !song.title.isEmpty { parts.append(song.title) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Generate

    /// The bottom **Generate** button — the primary action. Produces a goal-driven session from the
    /// active goals (or a due-based Quick session when there are none), materialised as a provisional
    /// routine for review. If nothing resolves (empty library, unresolvable goals) it surfaces a
    /// notice rather than pushing an empty routine.
    private var generateBar: some View {
        Button(action: generate) {
            Label("Generate today's session", systemImage: "wand.and.stars")
                .font(.futura(.body, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(PocketColor.practice, in: Capsule())
                .foregroundStyle(PocketColor.background)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .accessibilityLabel("Generate today's session")
    }

    /// What to do about an empty result — different advice for a different reason. An off-guitar
    /// session is built **only** from the player's loops (ADR 0139: it is as good as the loop
    /// library, and a brand-new player gets none at all), so telling them to add an exercise would
    /// send them off to make something this session can't use.
    private var emptyNoticeMessage: String {
        switch constraint {
        case .offGuitar:
            return "An away-from-your-instrument session is built from your loops. "
                 + "Set a loop over a section of one of your songs, then try again."
        case .none:
            return "Add an exercise, or give a \"learn a song\" goal a target song, then try again."
        }
    }

    /// Seed the duration picker from the profile's minutes-per-day once per screen (ADR 0113 S2
    /// consumer). Only a starting point — the player can change it freely, and an unset profile
    /// leaves the planner's own short default in place.
    private func seedLengthFromProfile() {
        guard !seededLength else { return }
        seededLength = true
        if let preferred = profiles.first?.minutesPerDay?.preferredSessionLength {
            length = preferred
        }
    }

    private func generate() {
        let active = activeGoals
        // The log's recency map is what gives a **loop** a time axis (ADR 0137). Both paths need it
        // now: an off-guitar Quick session is built entirely from loops, so without it every
        // candidate in it would rank as never-practised and the session would never rotate.
        let recency = PracticeLog.lastPracticedByUnit(practiceRuns.map(\.record))
        let blocks: [SessionBlock] = active.isEmpty
            ? PracticePlanner.planQuickSession(length: length, exercises: exercises, loops: loops,
                                               constraint: constraint, lastPracticed: recency)
            : PracticePlanner.planGoalSession(length: length, goals: active,
                                              exercises: exercises, loops: loops, songs: songs,
                                              profile: profiles.first,
                                              lastPracticed: recency,
                                              constraint: constraint)
        guard blocks.contains(where: { $0.unit != nil }) else {
            showingEmptyNotice = true
            haptic(.medium)
            return
        }
        let name = QuickSessionNaming.defaultName(existing: routines.map(\.name), date: .now,
                                                  constraint: constraint)
        draft = QuickSessionDraft(blocks: blocks, name: name, targetMinutes: length.minutes)
        haptic(.light)
    }
}

#Preview("Planner — with goals") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Goal.self, Exercise.self, Song.self, Loop.self, Routine.self, PracticeRun.self,
        configurations: .init(isStoredInMemoryOnly: true))
    let context = container.mainContext
    context.insert(Exercise(name: "Alternate picking", currentTempo: 70, commandTempo: 96))
    let speed = Goal(title: "Build speed", weight: 2.0,
                     skillIDs: ["pick.alternate", "pick.economy", "fret.legato"])
    context.insert(speed)
    context.insert(Goal(title: "Improvise", skillIDs: ["scale.pentatonic", "scale.blues"]))
    return NavigationStack { PlannerView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
