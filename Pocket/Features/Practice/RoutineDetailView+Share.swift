import SwiftUI

/// **Hand this routine over** (ADR 0188 S1) — the share control on the routine detail screen, and the
/// payload it builds. Split into its own file to keep `RoutineDetailView.swift` under the 400-line cap.
///
/// This is the half of ADR 0188 that ships first because it stands on its own: it writes a file and
/// reads none, so nothing here can damage a library, and the file it produces is the fixture the
/// receiving door (S2) is built against.
///
/// **Why it is on the detail screen and not the library row.** A routine is handed over deliberately,
/// to one person, usually after looking at it — `docs/positioning.md` §5's teacher handing a session to
/// a student. The library's hold menu is where the *bulk* verbs live (duplicate, favourite, delete),
/// and a share buried among them is a share nobody finds at the moment they want it.
extension RoutineDetailView {

    /// The share control. Read-only mode only, and only once the routine is in the store.
    ///
    /// Not while editing, because the sandbox's contents are provisional (`RoutineDetailView`'s
    /// Cancel/Save contract) and a file is not — a routine handed over mid-edit could contain blocks
    /// the sender then cancelled, and there is no taking it back. Not before the first Save, for the
    /// same reason: a provisional generated session is a proposal, not yet a routine.
    @ToolbarContentBuilder
    var shareToolbarItem: some ToolbarContent {
        if !isEditing && existsInStore {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: handover, preview: SharePreview(shareTitle)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .tint(PocketColor.practice)
            }
        }
    }

    /// What the share sheet calls it. Falls back rather than showing an empty preview title — a
    /// routine can legitimately be saved unnamed.
    var shareTitle: String {
        let name = routine.name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Practice routine" : name
    }

    /// The file, built from the routine as it stands.
    ///
    /// Rebuilt on every pass of the view's body, which is why `SharedPracticeFile` holds the payload
    /// rather than encoded bytes: this walks the blocks and the exercises they name, and stops there.
    /// The JSON is written once, later, only if the player actually picks a destination.
    ///
    /// Reads `routine` out of the **editing sandbox**, which is where this screen's routine always
    /// lives — and is safe precisely because the control is hidden in edit mode, so what the sandbox
    /// holds here is what the store holds.
    var handover: SharedPracticeFile {
        SharedPracticeFile(
            payload: SharedPracticeBuilder.routine(
                routine,
                appVersion: SupportDiagnostics.currentAppVersion(bundle: Bundle.main)),
            fileName: SharedPracticeFile.fileName(for: routine.name))
    }
}
