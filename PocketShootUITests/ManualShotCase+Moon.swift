import Foundation

/// A shoot in the moons (ADRs 0311, 0312), for the site: its landing page shows its screens in the
/// moon a visitor picks, so each screen is shot once per moon.
///
/// **All the moons in one run, on one seeded device.** `POCKET_SHOOT_MOON` names them, and each test
/// runs once per moon, relaunching the app in the next one. The seed is not the same twice: shot on
/// separate erased devices (2026-11-25), Home's *Jump back in* named three different songs across the
/// eight moons, and the Journal, the take and the song player differed the same way. On one device the
/// seed runs once (it refuses a store that already has songs), so a screen says the same thing in every
/// moon and only its colours change, which is what a visitor switching moons should see.
extension ManualShotCase {

    /// The moons this run shoots in, from `POCKET_SHOOT_MOON` (`blood`, or `"blood jade cold"`); empty
    /// for an ordinary run, which is the app's default, Blood Moon.
    ///
    /// `shoot-manual.sh` forwards it as `TEST_RUNNER_POCKET_SHOOT_MOON`, which is the only way a
    /// variable reaches the test runner (see `accessibilityAuditIsOn`), and refuses a name that isn't a
    /// moon: the app ignores an unknown one, so a typo would shoot Blood Moon under another moon's name.
    static var shootMoons: [String] {
        (ProcessInfo.processInfo.environment["POCKET_SHOOT_MOON"] ?? "")
            .split(separator: " ").map(String.init)
    }

    /// Runs the test once per moon, each pass with its own setUp and tearDown, so every capture test
    /// takes part without being written for it.
    override func invokeTest() {
        let moons = Self.shootMoons
        guard !moons.isEmpty else { return super.invokeTest() }
        for moon in moons {
            shootMoonPass = moon
            super.invokeTest()
        }
        shootMoonPass = nil
    }

    /// `-moonTheme <moon>` for `launchForShoot`, unless the test passes its own, as
    /// `AppStoreShots.testHomeInEachMoon` does: two values for one key in the arguments domain would
    /// leave which one the app reads to chance.
    ///
    /// An argument rather than a stored setting, for the reason `testHomeInEachMoon` gives: it wins
    /// over the stored value for that launch and leaves nothing on the simulator.
    func moonArguments(besides extra: [String]) -> [String] {
        guard let moon = shootMoonPass, !extra.contains("-moonTheme") else { return [] }
        return ["-moonTheme", moon]
    }

    /// `@jade` on the end of a capture's name in a moon run, so the eight captures of one screen can be
    /// told apart in the export. `file-shots.py` files by slug and so files none of them; a moon run's
    /// images are taken from its `export/manifest.json` by name.
    var moonSuffix: String { shootMoonPass.map { "@\($0)" } ?? "" }
}
