import SwiftUI
import UIKit
import XCTest
@testable import Pocket

/// **A sheet draws in the player's theme** (ADR 0312 D6, fixed in pocket-469).
///
/// A presented sheet doesn't inherit `\.moonTheme` from its presenter: its hosting controller reads the
/// value back from its own traits, which come from the window scene. With only the root's environment
/// set, Name the notes, Watch and every other sheet drew Blood Moon under any theme, and no test saw it,
/// because the unit tests resolve colours in an environment and never present anything. This one
/// presents a sheet, and a sheet inside it, in a real window, under a theme set the way the app sets it.
@MainActor
final class MoonThemeSheetTests: XCTestCase {

    func testASheetAndASheetInsideItDrawTheTheme() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let before = scene.traitOverrides.contains(MoonThemeTrait.self)
            ? scene.traitOverrides[MoonThemeTrait.self] : nil
        defer {
            if let before {
                scene.traitOverrides[MoonThemeTrait.self] = before
            } else {
                scene.traitOverrides.remove(MoonThemeTrait.self)
            }
        }
        MoonThemeScenes.apply(.cold, to: [scene])

        let log = SheetLog()
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(
            rootView: Presenter(log: log, level: 0).environment(\.moonTheme, .cold))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let deadline = Date().addingTimeInterval(10)
        while log.seen.count < 3, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }

        XCTAssertEqual(log.seen.map(\.level), [0, 1, 2], "the sheets didn't all open: \(log.seen)")
        for seen in log.seen {
            XCTAssertEqual(seen.theme, .cold, "level \(seen.level) drew \(seen.theme.name), not Cold Moon")
            XCTAssertEqual(seen.practice, Self.cold, "level \(seen.level)'s Practice colour isn't Cold Moon's")
        }
    }

    /// Cold Moon's Practice colour, in the appearance the test host is in.
    private static var cold: Color.Resolved {
        var environment = EnvironmentValues()
        environment.colorScheme = UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        environment.moonTheme = .cold
        return PocketColor.practice.resolve(in: environment)
    }
}

@MainActor
private final class SheetLog {
    struct Seen: CustomStringConvertible {
        let level: Int
        let theme: MoonTheme
        let practice: Color.Resolved
        var description: String { "\(level): \(theme.name)" }
    }

    var seen: [Seen] = []
}

/// A view that says what it drew in, then presents the next level as a sheet, two deep.
private struct Presenter: View {
    let log: SheetLog
    let level: Int
    @State private var presenting = false
    @Environment(\.self) private var environment

    var body: some View {
        Rectangle().fill(PocketColor.practice)
            .onAppear {
                log.seen.append(.init(level: level, theme: environment.moonTheme,
                                      practice: PocketColor.practice.resolve(in: environment)))
                if level < 2 { presenting = true }
            }
            .sheet(isPresented: $presenting) { Presenter(log: log, level: level + 1) }
    }
}
