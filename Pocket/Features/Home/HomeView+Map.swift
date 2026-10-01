import SwiftUI

/// Home's **map** (ADR 0197) — the destinations, two to a row, inside the three sections ADR 0102
/// grouped them into. This file replaces `HomeView+Learn.swift` and the four card properties that
/// were still in `HomeView.swift`: they had ended up in three files for no reason but the 400-line
/// cap, which meant nothing could see the map whole. Now one file owns it.
///
/// **Six are reachable.** The sixth is the player's own: the tile beside Toolkit opens a Toolkit tool they
/// pick, My tabs until they do (ADR 0235 D6). The Red Moon Oracle's door stays closed (ADR 0211).
/// `learnRow` carries the reasoning.
///
/// ### Why tiles
///
/// ADR 0102 considered a tile grid and rejected it — at **four** cards, when the strips still fit
/// and the subtitles still earned their height. Six strips do not fit: Home became a scroll whose
/// bottom half is a menu that has not changed since the app shipped and will not change again.
/// ADR 0197 reverses that call on the stated grounds that the count moved, and spends the reclaimed
/// height on `HomeStatsStrip` (ADR 0196) and the recent-routines rail — the two things on this
/// screen that are different from yesterday.
///
/// The subtitles go with the strips. That is the cost, and it is paid once: *"Your exercises &
/// training runs"* was worth reading on day one and has been re-read every day since. A hue and a
/// glyph are a map, learned once. `docs/manual/reference/home-and-library.md` stopped quoting them
/// in the same commit, because `scripts/check-manual.py` C9 holds every backticked token in the
/// reference wing to a real string literal and would otherwise have failed on six of them.
///
/// ### Two things that did **not** move
///
/// - **The accessibility labels are byte-identical**, subtitle wording and all. ADR 0102 §1 makes
///   them the UI-test contract — `RowUndoUITests`, `PracticeRunUITests`, `ExerciseInstrumentUITests`,
///   `RoutineLibraryUITests`, `OracleUITests`, `ToolkitUITests` and six shoot classes match on them —
///   and a description that has left the screen has not stopped being true. VoiceOver still gets the
///   sentence; the eye gets the map.
/// - **The Oracle's door.** The Oracle appears here and in no other section: not in the Journal and
///   not inside the Toolkit. `HomeView+Learn.swift` argued it at length, which is why its content is
///   carried here rather than deleted with it.
extension HomeView {

    /// The three sections, in the order ADR 0102 fixed: what you do, what you own, what you learn
    /// from. Sections breathe at the 20-pt rhythm; the two tiles inside one stay tight at 10.
    var homeMap: some View {
        VStack(alignment: .leading, spacing: 20) {
            HomeSection(title: "Practice") {
                HomeTileRow {
                    practiceTile
                    metronomeTile
                }
            }
            HomeSection(title: "Your stuff") {
                HomeTileRow {
                    songLibraryTile
                    journalTile
                }
            }
            HomeSection(title: "Learn") {
                HomeTileRow { learnRow }
            }
        }
    }

    // MARK: - Practice

    /// The top-level **Practice** space (ADR 0046) — where trainable units live and
    /// command-anchored runs happen. A push (it's a *place* with its own list and run screens),
    /// in the brand teal accent (`PocketColor.practice`, the brand hero).
    private var practiceTile: some View {
        NavigationLink { PracticeView() } label: {
            HomeTile(icon: "figure.run", title: "Practice",
                     tint: PocketColor.practice,
                     cardWash: PocketColor.practiceCardWash,
                     circleWash: PocketColor.practiceCircleWash)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Practice, your exercises and training runs")
    }

    /// The standalone metronome (plum, `PocketColor.metronome` — the one theme-invariant home
    /// hue), presented full-screen (it owns its own navigation + dismiss, ADR 0043).
    private var metronomeTile: some View {
        Button {
            showingMetronome = true
            Analytics.send(.toolOpened(tool: .metronome))
        } label: {
            HomeTile(icon: "metronome.fill", title: "Metronome",
                     tint: PocketColor.metronome,
                     cardWash: PocketColor.metronomeCardWash,
                     circleWash: PocketColor.metronomeCircleWash)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Metronome, standalone click and tempo trainer")
    }

    // MARK: - Your stuff

    /// The songs place, in its own warm **terracotta** identity (baked `library` tokens — no opacity
    /// blend, ADR 0062/0081). Together with the teal Practice and plum Metronome tiles this is the
    /// teal · plum · terracotta home triad (content / tool / songs).
    ///
    /// **The one tile that can carry a caption**, and only while the library is empty. The strip's
    /// subtitle was count-aware, and on a fresh install — six drills, one routine, no song
    /// (ADR 0112) — the count line read *Add a song to get started* and was Home's only word about
    /// it. The toolbar's green **+** is still the door; this keeps the sentence that points at it.
    private var songLibraryTile: some View {
        NavigationLink { LibraryView() } label: {
            HomeTile(icon: "music.note.list", title: "Song library",
                     tint: PocketColor.library,
                     cardWash: PocketColor.libraryCardWash,
                     circleWash: PocketColor.libraryCircleWash,
                     caption: songs.isEmpty ? librarySubtitle : nil)
        }
        .buttonStyle(.plain)
        // Still the whole sentence, count included — `ManualLibraryShots`, `ManualBareShots`,
        // `ManualMissingAudioShots` and `ManualShotCase+SongPlayer` all match `Song library,` as a
        // prefix and read what follows.
        .accessibilityLabel("Song library, \(librarySubtitle)")
    }

    /// The **Journal** space (ADR 0100) — the read-only practice-history destination that aggregates
    /// notes + takes across loops and exercises, in its own warm **gold** identity
    /// (`PocketColor.journal`), a fifth home hue kept clear of the teal · plum · terracotta triad and
    /// the indigo reference hub.
    private var journalTile: some View {
        NavigationLink { JournalTabView() } label: {
            HomeTile(icon: "book.closed.fill", title: "Journal",
                     tint: PocketColor.journal,
                     cardWash: PocketColor.journalCardWash,
                     circleWash: PocketColor.journalCircleWash)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Journal, your notes and practice takes")
    }

    // MARK: - Learn

    /// The **Learn** row: Toolkit, and beside it the player's own tile (ADR 0235 D6), in the half that
    /// held the Oracle's tile, hidden (ADR 0211).
    ///
    /// The Oracle's mechanism is finished; its **voice is not**. The reading it draws was rejected
    /// on reading it — every guard passes and the prose still sounds like an engineer describing a
    /// data structure — and `docs/backlog.md` parks the register as research with an explicit
    /// instruction not to tune it by ear again. So the door closes and nothing else moves: the
    /// screen, `LocalOracle`, the coordinator, all four guards and their nine test files stay
    /// exactly where they are.
    ///
    /// **A dimmed *Coming soon* tile was considered and refused.** It ships a control that does
    /// nothing, which is the placeholder App Store Guideline 2.1 names, and it promises a date on a
    /// problem nobody has scoped. An absent door claims nothing.
    ///
    /// **The Oracle is out of scope for 0235** (D7), so the test-only door is left as it was: open, it
    /// draws this row as it always has, Oracle and Toolkit. Where the Oracle goes if it comes back is
    /// decided when it does, so deleting this condition is no longer the whole of reopening it.
    @ViewBuilder
    private var learnRow: some View {
        if UITestRuntime.oracleDoorIsOpen {
            oracleTile
            toolkitTile
        } else {
            toolkitTile
            homeToolTile
        }
    }

    /// **The tile beside Toolkit is the player's** (ADR 0235 D6): it opens the Toolkit tool they pick,
    /// **My tabs** until they do, and takes that tool's name and glyph, so it always says where it goes.
    /// It wears Toolkit's indigo, since whatever it opens is a Toolkit tool (ADR 0197 D1, as amended).
    ///
    /// Two ways to change it, as Jump back in has (0193 D4): **hold it** and pick from the menu, or
    /// **Settings ▸ Practice ▸ Beside Toolkit**. Both write one key, bound to the named default.
    /// *Hold to change* sits under the name until it has been changed once (ADR 0197 D3, as amended).
    ///
    /// A link with a context menu, never a `Button` with a hold: that fires both. The spoken label is the
    /// tool's Toolkit row, so the tile and the row say the same thing (ADR 0197 D2).
    private var homeToolTile: some View {
        let tool = AppSettings.resolvedHomeTool(storedValue: homeToolRaw)
        return NavigationLink { ToolkitDestination(section: tool) } label: {
            HomeTile(icon: tool.info.icon, title: tool.info.title,
                     tint: PocketColor.toolkit,
                     cardWash: PocketColor.toolkitCardWash,
                     circleWash: PocketColor.toolkitCircleWash,
                     caption: AppSettings.homeToolCaption(chosen: homeToolChosen))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.info.spoken)
        .accessibilityIdentifier("home.toolTile")
        // A bare picker, as Jump back in's: a menu draws no heading over it, so it names nothing on screen.
        .contextMenu {
            Picker("Beside Toolkit", selection: homeToolChoice) {
                ForEach(ToolkitSection.allCases) { section in
                    Label(section.info.title, systemImage: section.info.icon).tag(section)
                }
            }
        }
    }

    /// Either door's choice: the tool, and that the tile has now been changed.
    private var homeToolChoice: Binding<ToolkitSection> {
        Binding(get: { AppSettings.resolvedHomeTool(storedValue: homeToolRaw) },
                set: { homeToolRaw = $0.rawValue; homeToolChosen = true })
    }

    /// The **Red Moon Oracle** (ADR 0187) — the reflective reading over the practice you have
    /// already done. The **sixth** home hue: crimson (`PocketColor.oracle`), kept clear of the
    /// teal · plum · terracotta triad, the indigo hub and the journal's gold. Not ADR 0081's Blood
    /// Moon, which D16 nominated and which turned out to *be* the terracotta family.
    ///
    /// A push, like the Toolkit beside it — it is a *place*, and one the player walks to. That is
    /// D2 in the navigation: the Oracle is **pull**. Nothing notifies that a reading is ready, this
    /// tile carries no badge and no count, and a reading that has become available waits silently
    /// until somebody opens it. A dot here would be the interruption ADR 0186 objected to, wearing
    /// a smaller coat.
    ///
    /// **The full name stays.** The mockup shortened it to *Oracle* to fit; it is `Red Moon Oracle`
    /// on its own navigation bar, in the manual and in `OracleUITests`, and a map whose tile calls a
    /// place something the place does not call itself is a map with a mistake on it. (It was long
    /// said here that the name wraps to two lines and that `HomeTile`'s equal-height row is what
    /// keeps the Toolkit level with it. Measured 2026-09-10 on an iPhone 17 at default Dynamic
    /// Type: **it does not wrap** — the Learn row is exactly as tall as the single-line `Practice`
    /// row. The equal-height row still does its job at larger type; the wrapping was the part
    /// nobody had checked.)
    ///
    /// ⚠ **Not reachable in a player's build** since ADR 0211 — `learnRow` draws this only when the
    /// test-only door is open. It is kept whole rather than commented out or deleted precisely so that
    /// this documentation is still true when it is reopened.
    private var oracleTile: some View {
        NavigationLink { OracleView() } label: {
            HomeTile(icon: "moon.stars.fill", title: "Red Moon Oracle",
                     tint: PocketColor.oracle,
                     cardWash: PocketColor.oracleCardWash,
                     circleWash: PocketColor.oracleCircleWash)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Red Moon Oracle, a reading of your week")
    }

    /// The **Toolkit** hub (ADR 0096) — the free, deterministic reference destination (tuner, My
    /// Chords, Glossary, Help & FAQs). A push, in the indigo/violet "study/reference" accent
    /// (`PocketColor.toolkit`).
    ///
    /// The label still **names the tuner first**. It needs no song and no library, and is the thing
    /// a guitarist reaches for every time they pick the instrument up — the strongest daily-habit
    /// hook in the app. That argument was made about a subtitle nobody sees any
    /// more, and it survives where the subtitle went: `ToolkitUITests` and `ManualToolkitShots` both
    /// match `Toolkit,` as a prefix, so the copy after the comma can still move.
    private var toolkitTile: some View {
        NavigationLink { ToolkitView() } label: {
            HomeTile(icon: "books.vertical.fill", title: "Toolkit",
                     tint: PocketColor.toolkit,
                     cardWash: PocketColor.toolkitCardWash,
                     circleWash: PocketColor.toolkitCircleWash)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Toolkit, tuner, your chords and a glossary")
    }
}

/// The map alone, at phone width, in both appearances — the check the build cannot make: that the hues
/// read as places rather than a swatch card, and, since ADR 0235, that two indigo tiles side by side
/// read as one space with two doors.
#Preview("Home map") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            HomeSection(title: "Practice") {
                HomeTileRow {
                    HomeTile(icon: "figure.run", title: "Practice", tint: PocketColor.practice,
                             cardWash: PocketColor.practiceCardWash,
                             circleWash: PocketColor.practiceCircleWash)
                    HomeTile(icon: "metronome.fill", title: "Metronome", tint: PocketColor.metronome,
                             cardWash: PocketColor.metronomeCardWash,
                             circleWash: PocketColor.metronomeCircleWash)
                }
            }
            HomeSection(title: "Your stuff") {
                HomeTileRow {
                    HomeTile(icon: "music.note.list", title: "Song library",
                             tint: PocketColor.library, cardWash: PocketColor.libraryCardWash,
                             circleWash: PocketColor.libraryCircleWash,
                             caption: "Add a song to get started")
                    HomeTile(icon: "book.closed.fill", title: "Journal", tint: PocketColor.journal,
                             cardWash: PocketColor.journalCardWash,
                             circleWash: PocketColor.journalCircleWash)
                }
            }
            HomeSection(title: "Learn") {
                HomeTileRow {
                    HomeTile(icon: "books.vertical.fill", title: "Toolkit",
                             tint: PocketColor.toolkit, cardWash: PocketColor.toolkitCardWash,
                             circleWash: PocketColor.toolkitCircleWash)
                    // The player's own tile, as a fresh install draws it (ADR 0235 D6).
                    HomeTile(icon: ToolkitSection.myTabs.info.icon, title: "My tabs",
                             tint: PocketColor.toolkit, cardWash: PocketColor.toolkitCardWash,
                             circleWash: PocketColor.toolkitCircleWash, caption: "Hold to change")
                }
            }
        }
        .padding(20)
    }
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
