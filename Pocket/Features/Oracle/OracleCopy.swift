import Foundation

/// Every fixed string the Oracle's screen shows (ADR 0187).
///
/// ### Two reasons this is its own file, and both matter
///
/// **The compiler.** `Text("a " + "b")` inside a `ViewBuilder` sends Swift's type checker hunting
/// through every overload of `+` in scope, and enough of them in one view stalls a build outright —
/// which is exactly what happened here before this file existed. Copy declared as `String` is
/// already typed by the time a view sees it.
///
/// **The reader.** D13's two fixed messages and the tone of the gate are the load-bearing prose in
/// this feature: the pain line must stay non-diagnostic, the distress card must stay human-written,
/// and neither may drift into advice. Keeping them in one place, away from layout, makes them
/// reviewable as writing rather than as view code — the same instinct that put the manual's
/// quotable strings under `check-manual.py`.
///
/// Every line here is owner-written and none of it is generated. That is the whole point of the two
/// D13 branches: a fixed answer, given the same way every time.
enum OracleCopy {

    /// What the screen is, in terms the feature can keep. It reflects; it does not assess — "how
    /// your week went" would promise a verdict (ADR 0070).
    static let subtitle = "A reading of the week you played — what you did, and what you wrote about it."

    static let drawButton = "Read the week"

    /// D15's justification, stated beside the date rather than left implicit. A gate that explains
    /// itself as *the reading reads a period* is a different object from one that says "come back
    /// Monday".
    static let cadenceReason = """
        A week's reflection needs a week of material — reading it twice on a Tuesday would read the \
        same journal twice.
        """

    /// D13's **pain** line. Fixed, owner-written and deliberately non-diagnostic: it names no
    /// condition, offers no exercise and gives no advice, because a keyword match is not a
    /// diagnosis and this app is not qualified to make one. It says what the app did — stopped
    /// suggesting work — and hands the judgement back.
    static let painNote = """
        Something you wrote mentions pain or strain, so there is nothing here suggesting more to \
        play. Rest is yours to judge.
        """

    /// Where the words came from. A reading written on the device and one written by a model are
    /// different things, and letting the player assume the second when they have the first is the
    /// kind of small lie that makes the rest of the app's promises harder to believe.
    static let sourceLocal = "Written on your phone, from your own practice log. Nothing left the device."
    static let sourceModel = "Written by the Oracle, from a summary of your week."

    // MARK: - D13's distress card

    /// **No model wrote any of this, and none was asked to.** The words are the same every time,
    /// which is the point: a generated response to somebody in a bad place is a gamble taken on
    /// their behalf, and the app declines to take it.
    enum Distress {
        static let title = "No reading this time."

        static let body = """
            Something you wrote sounded heavy, and a reflection on your practice week is not the \
            right answer to it. Nothing was sent anywhere.
            """

        /// Real signposting, deliberately not app-shaped — it points away from the practice log,
        /// because the practice log is not what would help. The UK/Ireland number is named because
        /// that is where Red Moon ships first; the directory covers everywhere else rather than
        /// pretending one number is global.
        static let signpost = """
            If you are struggling, talking to someone helps more than anything in this app can. In \
            the UK and Ireland, Samaritans are on 116 123, free, any time. Elsewhere, \
            findahelpline.com lists a service near you.
            """

        static let close = "The guitar will still be there."
    }
}
