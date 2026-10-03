import SwiftData
import SwiftUI

/// The **first-launch intake** (ADR 0113, Slice 2): short, skippable questions that declare what the
/// player wants — experience, genres, the dream, what they are working toward, minutes a day — so
/// the app can *curate* rather than infer everything from behaviour. One question per card, Red Moon
/// register (quiet, no urgency, no reveal-theatre, no paywall). Every question is skippable and the
/// whole thing is skippable; a player who skips it all gets a fully working app and a warm,
/// name-free home.
///
/// Distinct from the naming ceremony (`ArtistNamePromptSheet`): the intake is *not* where the artist
/// name is asked — that is earned after a first session. On finish (or skip) it writes
/// `Profile.setCuration`, adds the picked **long-term goals** (ADR 0246), and the parent sets
/// `artistIntakeSeen` so it never returns. The curation stays editable in Settings ▸ You, and the
/// goals in Practice ▸ Long-term goals.
struct ArtistIntakeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var experience: ArtistExperience?
    @State private var genres: Set<MusicGenre> = []
    @State private var dream: MusicalDream?
    /// Template ids, in the order tapped — which is their rank (ADR 0246).
    @State private var goalPicks: [String] = []
    @State private var minutes: PracticeMinutes?

    private enum Step { case experience, genres, dream, goals, minutes }

    /// The goals card follows the dream, and is left out after "Just unwind" (ADR 0246). Changing the
    /// dream on its own card cannot move the player: the dream is third either way.
    private var steps: [Step] {
        IntakeGoalOffer.asksForGoals(after: dream)
            ? [.experience, .genres, .dream, .goals, .minutes]
            : [.experience, .genres, .dream, .minutes]
    }
    private var stepCount: Int { steps.count }
    private var isLastStep: Bool { step == stepCount - 1 }

    var body: some View {
        ZStack {
            PocketColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Group {
                    switch steps[min(step, stepCount - 1)] {
                    case .experience: experienceStep
                    case .genres: genresStep
                    case .dream: dreamStep
                    case .goals: goalsStep
                    case .minutes: minutesStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.opacity)
                .id(step)
                bottomBar
            }
            .readableWidth()
        }
    }

    // MARK: - Header (intro + progress)

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("A few quick things")
                        .font(.futura(.title2, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text("So your practice fits you. Skip anything — nothing here is required.")
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button("Skip", action: finish)
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
                    .accessibilityLabel("Skip setup")
            }
            progressDots
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private var progressDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<stepCount, id: \.self) { index in
                Capsule()
                    .fill(index == step ? PocketColor.practice
                                        : PocketColor.surfaceBorder)
                    .frame(width: index == step ? 20 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.25), value: step)
            }
        }
        .accessibilityLabel("Question \(step + 1) of \(stepCount)")
    }

    // MARK: - Steps

    private var experienceStep: some View {
        questionScroll(title: "Where are you with the guitar?") {
            ForEach(ArtistExperience.allCases) { option in
                choiceRow(option.displayName, selected: experience == option) {
                    experience = experience == option ? nil : option
                }
            }
        }
    }

    private var genresStep: some View {
        questionScroll(title: "What do you want to play?",
                       subtitle: "Pick as many as you like.") {
            FlowLayout(spacing: 10) {
                ForEach(MusicGenre.allCases) { genre in
                    chip(genre.displayName, selected: genres.contains(genre)) {
                        if genres.contains(genre) { genres.remove(genre) } else { genres.insert(genre) }
                        haptic(.light)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    private var dreamStep: some View {
        questionScroll(title: "What's the dream?") {
            ForEach(MusicalDream.allCases) { option in
                choiceRow(option.displayName, selected: dream == option) {
                    dream = dream == option ? nil : option
                }
            }
        }
    }

    /// What the dream comes to (ADR 0246): long-term goals, the dream's closest first.
    private var goalsStep: some View {
        questionScroll(title: "What are you working toward?",
                       subtitle: "Pick up to \(IntakeGoalOffer.maxPicks), most important first. "
                           + "Change them any time in Practice ▸ Long-term goals.") {
            ForEach(IntakeGoalOffer.templates(for: dream)) { template in
                goalRow(template)
            }
        }
    }

    private var minutesStep: some View {
        questionScroll(title: "How long most days?") {
            ForEach(PracticeMinutes.allCases) { option in
                choiceRow(option.displayName, selected: minutes == option) {
                    minutes = minutes == option ? nil : option
                }
            }
        }
    }

    /// The shared scrolling body of a question card — a title, optional subtitle, and the option
    /// content the caller supplies.
    private func questionScroll<Content: View>(title: String, subtitle: String? = nil,
                                               @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.futura(.title3, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                VStack(spacing: 10) { content() }
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Navigation bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            if step > 0 {
                Button("Back") { advance(by: -1) }
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Spacer()
            Button(action: next) {
                Text(isLastStep ? "Done" : "Continue")
                    .font(.futura(.headline))
                    .foregroundStyle(PocketColor.background)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 40)
                    .background(PocketColor.practice, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
        .padding(.top, 8)
    }

    private func next() {
        if isLastStep { finish() } else { advance(by: 1) }
    }

    private func advance(by delta: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            step = min(max(0, step + delta), stepCount - 1)
        }
        haptic(.light)
    }

    /// Persist whatever was chosen (skipped fields stay `nil`/empty) and leave. Called by both the
    /// final "Done" and the top "Skip" — an all-skip run just writes an empty curation, which is a
    /// no-op the app treats as "no declared preferences yet."
    private func finish() {
        Profile.setCuration(experience: experience, genres: Array(genres),
                            dream: dream, minutesPerDay: minutes, in: context)
        addPickedGoals()
        haptic(.medium)
        dismiss()
    }

    /// The goals card's picks become long-term goals, ranked as tapped (ADR 0246). Nothing is added
    /// when the card is no longer part of the flow: a player who picked goals, went back and chose
    /// "Just unwind" has said they do not want them.
    private func addPickedGoals() {
        guard IntakeGoalOffer.asksForGoals(after: dream), !goalPicks.isEmpty else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<LongTermGoal>())) ?? 0
        let templates = goalPicks.compactMap(GoalTemplateLibrary.template)
        for goal in LongTermGoalStore.makeGoals(from: templates, below: existing) {
            context.insert(goal)
        }
        try? context.save()
    }
}

// Kept out of the struct body so the type stays within `type_body_length`; same-file, so the
// rows still read the view's private state.
private extension ArtistIntakeView {
    // MARK: - Option controls

    /// A full-width single-select row (tap to select, tap again to clear).
    private func choiceRow(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { action(); haptic(.light) } label: {
            HStack {
                Text(label)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.futura(.footnote, weight: .bold))
                        .foregroundStyle(PocketColor.practice)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? PocketColor.practiceCardWash : PocketColor.surfaceSubtle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(selected ? PocketColor.practice : PocketColor.surfaceBorder,
                                  lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// A goal template: its title and blurb and, once picked, its rank. The number is what tells the
    /// player that the order they tap in matters. Rows past the cap dim and stop responding.
    private func goalRow(_ template: GoalTemplate) -> some View {
        let rank = goalPicks.firstIndex(of: template.id).map { $0 + 1 }
        let isFull = rank == nil && goalPicks.count >= IntakeGoalOffer.maxPicks
        return Button {
            goalPicks = IntakeGoalOffer.toggling(template.id, in: goalPicks)
            haptic(.light)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(template.title)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(template.blurb)
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if let rank {
                    Text("\(rank)")
                        .font(.futura(.footnote, weight: .bold))
                        .foregroundStyle(PocketColor.background)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(PocketColor.practice))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(rank != nil ? PocketColor.practiceCardWash : PocketColor.surfaceSubtle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(rank != nil ? PocketColor.practice : PocketColor.surfaceBorder,
                                  lineWidth: rank != nil ? 1.5 : 1)
            )
            .opacity(isFull ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isFull)
        .accessibilityAddTraits(rank != nil ? .isSelected : [])
        .accessibilityValue(rank.map { "Number \($0)" } ?? "")
    }

    /// A wrapping multi-select chip (genres).
    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.futura(.subheadline))
                .foregroundStyle(selected ? PocketColor.background : PocketColor.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(selected ? PocketColor.practice : PocketColor.surfaceSubtle)
                )
                .overlay(
                    Capsule().strokeBorder(selected ? .clear : PocketColor.surfaceBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview {
    Color.clear
        .fullScreenCover(isPresented: .constant(true)) { ArtistIntakeView() }
        .modelContainer(for: Profile.self, inMemory: true)
}
