import XCTest

/// The accessibility half of the shoot (ADR 0213).
///
/// **Why this rides the shoot rather than owning a walk.** An accessibility audit needs the app in
/// every state it has, and the shoot already erases, seeds, unlocks and drives sixty-odd of them —
/// navigation that stays correct because the manual's figures depend on it. A second walk written
/// for the audit would be a copy of that, maintained by nobody, and it would rot the first time a
/// sheet moved. So the audit is an *attachment*, not a test: every `capture` already photographs a
/// screen and records what it asserted, and this adds a third artefact beside those two.
///
/// **What it deliberately records that `diagnosis(for:in:)` does not: elements with no label.**
/// That function skips them (`guard !label.isEmpty`) because it is answering "what does this screen
/// call things", and an unnamed element cannot be an answer. Here the unnamed element is the
/// finding — an icon-only button with no label is precisely what VoiceOver reads out as its SF
/// Symbol name.
///
/// **What it cannot see, and what that means.** XCUITest exposes no accessibility *traits*, so
/// `elementType` is the only proxy for "is this a button", and it exposes nothing at all about
/// VoiceOver's focus order, swipe order or how a label sounds read aloud. Those are not gaps to
/// engineer around — they are the reason ADR 0213 keeps a human device pass. Treat a clean report
/// from this as "no absences", never as "accessible".
extension ManualShotCase {

    /// Whether to dump the tree beside each figure.
    ///
    /// **Off by default, because the manual's shoot must not pay for the audit.** Reading label,
    /// value, identifier, frame and enabled-state off several hundred elements is a round trip each,
    /// and a full shoot is already ~40 minutes across eight passes. The audit is an occasional job;
    /// the figures are a routine one.
    ///
    /// Set from the shell as `TEST_RUNNER_POCKET_SHOOT_AX=1`. The prefix is not decoration:
    /// `xcodebuild` passes variables to the *test runner* process only when they carry it, and
    /// plain `POCKET_SHOOT_AX=1` reaches the shell and no further — which fails as a silent
    /// no-op, i.e. a clean audit report of nothing at all. `shoot-manual.sh` handles the prefix.
    static var accessibilityAuditIsOn: Bool {
        ProcessInfo.processInfo.environment["POCKET_SHOOT_AX"] == "1"
    }

    /// How many elements one screen's dump will walk before stopping.
    ///
    /// Higher than `diagnosisScanCap`, and for the opposite reason. That cap protects a *failure
    /// message* from being too long to read; this one protects a run's duration, and the thing it
    /// is capping is the input to a script. A truncated dump is recorded as truncated so the script
    /// can say so rather than reporting a short screen as a clean one.
    static let accessibilityScanCap = 800

    /// One screen's accessibility tree, as JSON, for `scripts/ax-audit.py`.
    ///
    /// JSON rather than the `.context` file's prose: this one is read by a script, and a format that
    /// a human skims and a parser guesses at is how the manual's own figure rects were once
    /// eyeballed instead of measured.
    @MainActor
    func accessibilityDump(of app: XCUIApplication, slug: String, screen: String) -> String {
        let window = app.windows.firstMatch.frame
        var elements: [[String: Any]] = []

        for candidate in app.descendants(matching: .any).allElementsBoundByAccessibilityElement {
            let frame = candidate.frame
            var entry: [String: Any] = [
                "type": Self.name(for: candidate.elementType),
                "label": candidate.label,
                "identifier": candidate.identifier,
                "enabled": candidate.isEnabled,
                // Not `isHittable`: it hit-tests, which is a round trip per element on top of the
                // ones above, and the rules this feeds are answered by the frame. An element with
                // an empty frame, or one outside the window, is reported as such and the script
                // decides — rather than being dropped here, where nothing can see the decision.
                "inWindow": !frame.isEmpty && window.contains(frame),
                "frame": ["x": frame.origin.x, "y": frame.origin.y,
                          "w": frame.width, "h": frame.height]
            ]
            if let value = candidate.value as? String, !value.isEmpty {
                entry["value"] = value
            }
            elements.append(entry)
            if elements.count >= Self.accessibilityScanCap { break }
        }

        let payload: [String: Any] = [
            "slug": slug,
            "screen": screen,
            "truncated": elements.count >= Self.accessibilityScanCap,
            "window": ["w": window.width, "h": window.height],
            "elements": elements
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload,
                                                     options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            // Never fail the shoot over the audit: a figure is the run's job, this is a passenger.
            return #"{"slug": "\#(slug)", "error": "the tree would not serialise"}"#
        }
        return text
    }

    /// The types a report names, as a table rather than a `switch`.
    ///
    /// Only the types the rules reason about are spelled out; everything else keeps its raw value,
    /// which is enough to tell two unnamed containers apart without pretending this is a complete
    /// enumeration of a type that gains cases between Xcode versions. A table because a seventeen-arm
    /// `switch` returning a string literal per arm is a dictionary written the long way — and it is
    /// one SwiftLint fails on cyclomatic complexity, correctly.
    static let elementTypeNames: [XCUIElement.ElementType: String] = [
        .button: "button", .image: "image", .staticText: "staticText", .cell: "cell",
        .switch: "switch", .slider: "slider", .textField: "textField",
        .secureTextField: "secureTextField", .textView: "textView", .link: "link",
        .menuItem: "menuItem", .navigationBar: "navigationBar", .tabBar: "tabBar",
        .toolbar: "toolbar", .other: "other", .window: "window", .application: "application"
    ]

    /// `XCUIElement.ElementType` as a name a report can print.
    static func name(for type: XCUIElement.ElementType) -> String {
        elementTypeNames[type] ?? "type\(type.rawValue)"
    }
}
