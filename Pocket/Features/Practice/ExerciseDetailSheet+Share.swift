import SwiftUI

/// **Hand this drill over** (ADR 0209 S1) — the share control on the exercise detail sheet, and the
/// payload it builds. Split into its own file to keep `ExerciseDetailSheet.swift` under the 400-line
/// cap, the same reason `RoutineDetailView+Share.swift` exists.
///
/// This is the sending half of ADR 0209, and it ships first for ADR 0188 S1's reason: it writes a
/// file and reads none, so nothing here can damage a library, and the file it produces is the
/// fixture the receiving door is built against.
///
/// **Why this sheet.** It is the drill's read-only reference surface (ADR 0077) — the place you go to
/// see what an exercise *is*. A drill is handed over deliberately, usually after looking at it, which
/// is the same argument ADR 0188 made for putting the routine's share on its detail screen rather
/// than in the library's hold menu. That menu is where the bulk verbs live (details, duplicate,
/// favourite, delete), and a share buried among them is a share nobody finds at the moment they want
/// it.
///
/// **Sending is not gated** (ADR 0209 D3). Every other exercise verb in this app asks
/// `AccessPolicy.canAuthor` first; this one deliberately does not. A free player can run
/// free-template drills, and handing one to a friend authors nothing here, costs nothing, and is
/// `docs/positioning.md` §1's multiplier working in the app's favour. The gate belongs on the
/// receiving side, where a drill is actually minted.
extension ExerciseDetailSheet {

    /// The share control.
    ///
    /// Unconditional, unlike the routine's — which hides itself while editing, because a routine
    /// handed over mid-edit could contain blocks the sender then cancelled. This sheet has no edit
    /// mode and no Cancel: its two editable fields commit on Done and are otherwise the model's, so
    /// there is no provisional state a file could capture. What it does have is the in-flight
    /// description, which `handover` reads rather than ignores.
    @ToolbarContentBuilder
    var shareToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            ShareLink(item: handover, preview: SharePreview(shareTitle)) {
                Image(systemName: "square.and.arrow.up")
            }
            .tint(PocketColor.practice)
        }
    }

    /// What the share sheet calls it. Falls back rather than showing an empty preview title — a drill
    /// can legitimately be saved unnamed, the same way a routine can.
    var shareTitle: String {
        let name = exercise.name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Practice exercise" : name
    }

    /// The file, built from the drill as it stands **on screen**.
    ///
    /// `notes:` is the point of this line. The description is `@State` until Done (see
    /// `ExerciseDetailSheet.notes`), so building the payload from the model alone would hand over a
    /// drill whose description is the one the sender just replaced — silently, with no way to tell
    /// from the file. Mastery is the sheet's other uncommitted field and needs no such care: a share
    /// drops it either way (ADR 0188 D5).
    ///
    /// Rebuilt on every pass of the view's body, which is why `SharedPracticeFile` holds the payload
    /// rather than encoded bytes: this maps one drill and stops. The JSON is written once, later,
    /// only if the player actually picks a destination.
    var handover: SharedPracticeFile {
        SharedPracticeFile(
            payload: SharedPracticeBuilder.exercise(
                exercise,
                appVersion: SupportDiagnostics.currentAppVersion(bundle: Bundle.main),
                notes: notes),
            fileName: SharedPracticeFile.fileName(for: exercise.name, fallback: "exercise"))
    }
}
