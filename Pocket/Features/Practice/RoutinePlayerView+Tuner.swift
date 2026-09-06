import SwiftUI

/// The routine player's **tune-up** (ADR 0195) — the one screen before block 1, and the `Tune up`
/// button on the two surfaces between blocks. `TunerView` already exists; this is placement.
///
/// **Why the placements are all the player's own screens, and never a running block.** A tuner needs
/// `.playAndRecord`; a block holds `.playback`. Reaching the tuner from a block would mean flipping
/// the shared session's category out from under a live `AVAudioEngine`, and — where the block was
/// authored to capture a take (ADR 0179) — putting it back afterwards is `configurePlaybackSession`,
/// the exact move that removes input from the route, stops the `AVAudioRecorder`, and gets a real
/// take deleted as an accidental half-second tap (see `AudioPlumbing.ensurePlaybackSession`, which
/// exists because that destroyed real playing on 2026-08-05). The offer screen, the rest countdown
/// and the Done screen are all silent, and on all three the block's run screen has already been torn
/// down — so its engine is stopped and its take is finalised before the tuner is ever built. The
/// hazard is designed out rather than guarded against; ADR 0195 D3 records what that costs.
///
/// **Offered, never a gate.** A routine opens by *asking* — a three-answer question whose last answer
/// silences it for good — and only a `Tune up` takes you to the tuner. Nothing here says whether you
/// are in tune; the tuner does that, and only about a string you choose to play it. The
/// between-blocks button is not gated at all: it is a way to reach something, not a thing that
/// happens to you.
///
/// **The question, not the screen, is what greets you (ADR 0195 D2, amended after a device pass).**
/// This began as the tuner itself, unannounced, behind a default-off setting. On the phone that read
/// as the routine having been replaced by something else, and the setting meant nobody would ever
/// have seen it anyway — which is the burial this work exists to undo. One tap to answer, one tap to
/// never be asked again, and the full tuner screen kept intact as what *yes* leads to.
///
/// **And the question is the app's own screen, not a system alert (ADR 0195 D7).** The first cut
/// handed it to `.alert`, which cannot be branded and needed a backdrop to sit over anyway — so it
/// took the whole screen and looked like nothing else in the app. Same three answers, same tap
/// count, in Futura on the app's ground.
extension RoutinePlayerView {

    // MARK: - Before block 1

    /// Put the question if the player has not turned it off — returning whether it did, so `onAppear`
    /// knows not to start the session underneath it.
    ///
    /// Decided **once** per presentation of the player, not once per `onAppear`: that callback
    /// re-fires on every return to the front, and a second prompt arriving between blocks four and
    /// five is the "never repeated within a session" rule broken. Skipped entirely for a routine with
    /// nothing to play — an all-orphaned one lands straight on the summary, and asking whether to
    /// tune up for it would be the app asking you to prepare for nothing.
    func promptTuneUpIfWanted() -> Bool {
        let offer = RoutineTuneUpOffer.shouldOffer(alreadyDecided: tuneUpDecided,
                                                   isEnabled: tuneUpAsk,
                                                   hasStages: !player.stages.isEmpty)
        tuneUpDecided = true
        showingTuneUpPrompt = offer
        return offer
    }

    /// The question, drawn on the app's own ground (ADR 0195 D7).
    ///
    /// This was a SwiftUI `.alert`, and an alert is the one surface in the app that cannot be
    /// branded — no font hook, no colour hook — so the tune-up question was the only screen in the
    /// routine flow not set in Futura. It was also already costing a full screen, since the alert
    /// needed a backdrop to sit over: the whole height, and none of the benefit.
    ///
    /// **Restrained on purpose.** `ArtistNamePromptSheet` is the ceremony precedent — crescent seal,
    /// staged fade, dark-locked — and it is earned there because it happens *once, ever*. This asks
    /// at the top of every routine, and ceremony scales inversely with frequency: the same treatment
    /// here would read as something to get past by the fourth session. So: the app's ground, its
    /// type, its capsule, and no choreography.
    var tuneUpPrompt: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "tuningfork")
                .font(.futura(.title))
                .foregroundStyle(PocketColor.practice)
                .frame(width: 84, height: 84)
                .background(Circle().fill(PocketColor.practiceCircleWash))
                .accessibilityHidden(true)
                .padding(.bottom, 28)

            VStack(spacing: 12) {
                Text("Tune up first?")
                    .font(.futura(.title2, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                Text("Check your strings before you start. You can always tune between blocks.")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            Spacer()

            answers
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The three answers, stacked. `Tune up` takes the capsule — the same one the routine's own
    /// **Start** button wears two screens earlier (`RoutineDetailView.startBar`), because this is the
    /// same journey and a second button language inside it would read as a second app.
    ///
    /// `Don't ask again` sits **last**, below `Not now`, which inverts the alert's cancel-role
    /// ordering on purpose: on a screen the eye travels down, and the answer that ends the feature
    /// permanently should not be the one nearest the thumb.
    ///
    /// It is a third *answer* and not a checkbox because a checkbox reaches the same outcome in one
    /// *more* tap — tick, then dismiss. That reasoning survived the restyle unchanged; what changed
    /// is only what the buttons are made of.
    @ViewBuilder
    private var answers: some View {
        VStack(spacing: 18) {
            Button {
                showingTuneUpPrompt = false
                showingTuneUpOffer = true
                haptic(.light)
            } label: {
                Text("Tune up")
                    .font(.futura(.body, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(PocketColor.practice, in: Capsule())
                    .foregroundStyle(PocketColor.background)
            }

            VStack(spacing: 4) {
                secondaryAnswer("Not now", hint: "Starts the routine without tuning") {
                    dismissPrompt()
                }
                secondaryAnswer("Don't ask again",
                                hint: "Starts the routine and turns off Ask to tune up in Settings") {
                    // Writes the same key `Settings ▸ Routines` writes, so the row is never out of
                    // date with what the player just told the prompt.
                    tuneUpAsk = false
                    dismissPrompt()
                }
            }
            // `.tint` as well as `.foregroundStyle`: a `Button`'s label takes the accent colour, and
            // an ancestor's foreground style alone does not reliably win against it.
            .font(.futura(.subheadline))
            .foregroundStyle(PocketColor.textSecondary)
            .tint(PocketColor.textSecondary)
        }
    }

    /// One of the two quiet answers, padded to a **44 pt** target rather than left at the ~20 pt its
    /// text would occupy (design brief §2). These sit close together and one of them switches the
    /// feature off for good, so a mis-tap here is the expensive kind; `contentShape` makes the whole
    /// padded width tappable instead of the glyphs alone.
    private func secondaryAnswer(_ title: String,
                                 hint: String,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityHint(hint)
    }

    /// Answer the question without tuning: the session begins, which is what the player asked for.
    func dismissPrompt() {
        showingTuneUpPrompt = false
        beginSession()
    }

    /// Where `Tune up` leads: the real tuner, with a way on pinned to the bottom.
    ///
    /// Unchanged from the first cut of this ADR — what changed is that it is now an *answer* rather
    /// than the default. Once a player has said yes, a full screen is right: they are tuning, and a
    /// tuner in a corner of something else is a worse tuner. The button says `Start practising`, not
    /// *Skip*, because leaving here is the beginning of the session, not the abandonment of a step.
    var tuneUpOfferView: some View {
        TunerView()
            .safeAreaInset(edge: .bottom) {
                // The routine's own capsule, not `.borderedProminent` — see `answers`.
                Button(action: startPractising) {
                    Text("Start practising")
                        .font(.futura(.body, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(PocketColor.practice, in: Capsule())
                        .foregroundStyle(PocketColor.background)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
            // The offer sits outside the per-block session chrome, so it needs its own way out —
            // the same reason the Done screen carries one.
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(PocketColor.textSecondary)
                    .accessibilityLabel("Close player")
                }
            }
    }

    /// Leave the offer and begin the session. The offer held `player.start()` back rather than
    /// running underneath: a routine whose first item is a rest would otherwise have counted its
    /// breather down while the player was still tuning.
    func startPractising() {
        showingTuneUpOffer = false
        beginSession()
    }

    // MARK: - Between blocks

    /// The `Tune up` toolbar button for the rest and Done screens — ungated, because reaching a tool
    /// is not something that happens to you. A tuning fork rather than a word: both screens already
    /// carry a leading exit, and ADR 0126's grammar keeps a nav bar's items to glyphs.
    var tuneUpButton: some View {
        Button { showingTuner = true; haptic(.light) } label: {
            Image(systemName: "tuningfork")
        }
        .tint(PocketColor.practice)
        .accessibilityLabel("Tune up")
    }

    /// The tuner as a sheet, in its own stack so it keeps its title and its Tune settings button.
    /// Leading `Done`, because the trailing side is spoken for.
    var tunerSheet: some View {
        NavigationStack {
            TunerView()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { showingTuner = false }
                            .tint(PocketColor.toolkit)
                    }
                }
        }
    }
}
