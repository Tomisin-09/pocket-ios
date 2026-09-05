import SwiftUI

/// The home hub's **Learn** section (ADR 0187 D16) — the Red Moon Oracle and the Toolkit.
///
/// ### Why this section exists, and why it is the Oracle's only door
///
/// ADR 0102 §2 pre-scoped this and `HomeView` has carried the comment holding the slot ever since:
/// Toolkit rode in *Your stuff* on the understanding that it would leave for a section of its own
/// once there was a second thing to learn from. Home is now **Practice · Your stuff · Learn**.
///
/// The two places the Oracle deliberately does **not** appear are as load-bearing as the place it
/// does:
///
/// - **The Journal gets nothing — not even a locked row.** ADR 0144 D2 exempts the Journal on an
///   explicit trust argument: *what you wrote and what you recorded is yours, and a lapsed
///   subscription must not take it back*. Putting a paid door inside the one space that promise
///   protects would undo it. The Oracle reads the journal; it does not stand in it.
/// - **The Toolkit is not its home either.** ADR 0144 notes the Toolkit *"already contains zero
///   `isPro` reads, so leaving it free costs nothing to build"* — putting the app's first metered,
///   network-calling surface inside the one space whose proposition is being gate-free would
///   undercut the App Review mitigation 0144 requires to be named in the review notes.
///
/// ### The move
///
/// `toolkitCard` is here **verbatim** — the same body, the same hues, the same accessibility label.
/// ADR 0102 §1 makes that a requirement rather than a courtesy: `ToolkitUITests` matches the label,
/// and a section change is not a reason for a smoke test to go red. It lives in this file rather
/// than `HomeView.swift` because `private` is file-scoped in Swift, so an extension elsewhere
/// cannot see it — and because `HomeView.swift` sits close enough to SwiftLint's 400-line ceiling
/// that the sixth card had nowhere to land.
extension HomeView {

    // MARK: - Oracle card

    /// The **Red Moon Oracle** (ADR 0187) — the reflective reading over the practice you have
    /// already done. The **sixth** home hue: crimson (`PocketColor.oracle`), kept clear of the
    /// teal · plum · terracotta triad, the indigo hub and the journal's gold.
    ///
    /// Not ADR 0081's Blood Moon, which D16 nominated and which turned out to *be* the terracotta
    /// family — its light value is byte-for-byte the Song library's. See `PocketColor.oracle`.
    ///
    /// A push, like the Toolkit beside it — it is a *place*, and one the player walks to. That is
    /// D2 in the navigation: the Oracle is **pull**. Nothing notifies that a reading is ready, this
    /// card carries no badge and no count, and a reading that has become available waits silently
    /// until somebody opens it. A dot here would be the interruption ADR 0186 objected to, wearing
    /// a smaller coat.
    var oracleCard: some View {
        NavigationLink { OracleView() } label: {
            // The subtitle says what it *is*, not what it will tell you. "See how your week went"
            // would promise a verdict, which is the one thing this feature is built not to give
            // (ADR 0070).
            //
            // **Kept short enough to set on one line.** The first draft — "A reading of the week you
            // played" — wrapped, which made this card taller than the five beside it and broke the
            // even rhythm of the strips. Nothing catches that: it builds, it lints, and every test
            // passes. It took a screenshot.
            HomeNavCard(icon: "moon.stars.fill", title: "Red Moon Oracle",
                        subtitle: "A reading of your week",
                        tint: PocketColor.oracle,
                        cardWash: PocketColor.oracleCardWash,
                        circleWash: PocketColor.oracleCircleWash)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Red Moon Oracle, a reading of your week")
    }

    // MARK: - Toolkit card

    /// The **Toolkit** hub (ADR 0096) — the free, deterministic reference destination (My Chords +
    /// Glossary in Slice 1). A push (it's a *place* with its own list of sections), in the new
    /// indigo/violet "study/reference" accent (`PocketColor.toolkit`), the fourth home hue kept clear
    /// of the teal · plum · terracotta triad above it.
    var toolkitCard: some View {
        NavigationLink { ToolkitView() } label: {
            // The subtitle **names the tuner first**, deliberately. The pocket-170 rewrite that
            // replaced "Chords, scales & theory reference" was fixing an over-promise and was right
            // on the day — but the Tuner (ADR 0115) and Help & FAQs (ADR 0145) both landed inside
            // the Toolkit afterwards and neither reached this card, so it started *under*-promising
            // instead. The tuner is free forever (ADR 0144), needs no song and no library, and is
            // the thing a guitarist reaches for every time they pick the instrument up — it is the
            // strongest daily-habit hook in the app, and it was sitting behind a card that didn't
            // mention it. Help & FAQs stays unlisted: one line only holds so much, and it has a
            // second door in Settings → About.
            HomeNavCard(icon: "books.vertical.fill", title: "Toolkit",
                        subtitle: "Tuner, your chords & a glossary",
                        tint: PocketColor.toolkit,
                        cardWash: PocketColor.toolkitCardWash,
                        circleWash: PocketColor.toolkitCircleWash)
        }
        .buttonStyle(.plain)
        // Kept in step with the subtitle by hand. `ToolkitUITests` matches on `BEGINSWITH "Toolkit,"`
        // rather than the whole string, so the copy can move without breaking the smoke test.
        .accessibilityLabel("Toolkit, tuner, your chords and a glossary")
    }
}
