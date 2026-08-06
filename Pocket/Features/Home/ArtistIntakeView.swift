import SwiftData
import SwiftUI

/// The **first-launch intake** (ADR 0113, Slice 2): four short, skippable questions that declare what
/// the player wants — experience, genres, the dream, minutes a day — so the app can *curate* rather
/// than infer everything from behaviour. One question per card, Red Moon register (quiet, no urgency,
/// no reveal-theatre, no paywall). Every question is skippable and the whole thing is skippable; a
/// player who skips it all gets a fully working app and a warm, name-free home.
///
/// Distinct from the naming ceremony (`ArtistNamePromptSheet`): the intake is *not* where the artist
/// name is asked — that is earned after a first session. This only collects the curation fields, which
/// feed today's consumers (a fresh exercise's tempo default, the planner's session length) and the
/// planner emphasis mix later (Slice 3). On finish (or skip) it writes `Profile.setCuration` and the
/// parent sets `artistIntakeSeen` so it never returns; everything stays editable in Settings.
struct ArtistIntakeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Set when the disclosure footnote has been shown and the intake left (ADR 0147). Same stored
    /// key as `HomeView`'s copy — `@AppStorage` on one key is shared state, so writing it here is
    /// seen there immediately.
    @AppStorage(AppSettings.Key.analyticsPromptSeen) private var analyticsDisclosureSeen = false

    @State private var step = 0
    @State private var experience: ArtistExperience?
    @State private var genres: Set<MusicGenre> = []
    @State private var dream: MusicalDream?
    @State private var minutes: PracticeMinutes?

    private let stepCount = 4
    private var isLastStep: Bool { step == stepCount - 1 }

    var body: some View {
        ZStack {
            PocketColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Group {
                    switch step {
                    case 0: experienceStep
                    case 1: genresStep
                    case 2: dreamStep
                    default: minutesStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.opacity)
                .id(step)
                analyticsDisclosure
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

    // MARK: - Analytics disclosure (ADR 0147)

    /// The "clear and comprehensive information" the DUAA Sch A1 para 5 exception is conditional on.
    ///
    /// **Outside the step `Group` and above `bottomBar` on purpose**, so it is present on all four
    /// steps — including step 0, which is where **Skip** exits. A disclosure a player can leave
    /// without ever seeing would not satisfy the condition, and the whole legal basis rests on it.
    ///
    /// A footnote rather than a fifth step, deliberately: ADR 0120 §3 rejected adding a screen here
    /// because it would tax the activation flow analytics exists to measure. That objection is to a
    /// screen with a *decision* in it. This asks nothing and blocks nothing, so the objection does
    /// not carry — and it reclaims the intake and first session, which 0120 wrote off as permanently
    /// unmeasurable.
    ///
    /// Absent entirely under `.ask`, where consent is still asked for separately (ADR 0120).
    @ViewBuilder
    private var analyticsDisclosure: some View {
        if consentModel == .notify {
            Text("Red Moon counts which features get used, anonymously — never your playing. "
                 + "Turn it off any time in Settings ▸ Privacy.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 4)
        }
    }

    private var consentModel: AnalyticsPolicy.ConsentModel {
        AnalyticsPolicy.consentModel(regionCode: Locale.current.region?.identifier)
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
        // Under `.notify` the footnote above *is* the disclosure, and both exits from this screen
        // route through here — so leaving by either one means it has been shown. Recording that
        // stops `maybeOfferProfileMoment` later raising the catch-up sheet at somebody who was
        // already told (ADR 0147 §2). Untouched under `.ask`, where the consent sheet still owns
        // this flag.
        if consentModel == .notify {
            analyticsDisclosureSeen = true
        }
        haptic(.medium)
        dismiss()
    }
}

#Preview {
    Color.clear
        .fullScreenCover(isPresented: .constant(true)) { ArtistIntakeView() }
        .modelContainer(for: Profile.self, inMemory: true)
}
