import UIKit

/// Opens the system share sheet on a file, from a plain button (ADR 0236).
///
/// `ShareLink` is the first choice, and the take menus use it. It can't be used from a **row inside a
/// `Form` in a sheet**: a presentation raised there is lost, or takes the sheet down with it, which
/// `SongDetailsSheet` already records for its own editors (see `ReferenceLinkEditing`). A `ShareLink`
/// row in Song details never opened the share sheet in testing (2026-10-01), with a URL item or a
/// `Transferable` one, while the same `ShareLink` in a take's hold menu did. Those editors fixed it by
/// hoisting their state to the `NavigationStack`, but a `ShareLink` presents itself and can't be hoisted.
///
/// The sheet takes a second or more to appear: it waits on a system service that runs out of process.
///
/// So a row hands the file to UIKit, which presents `UIActivityViewController` from whatever is on
/// top. That is the controller SwiftUI's own share sheet is, so the player sees the same sheet.
///
/// On iPad the sheet is a popover and needs an anchor. It is centred on the presenting view with no
/// arrow, since a row deep in a sheet makes a poor anchor.
@MainActor
enum SharePresenter {

    /// Show the share sheet for `url`. Does nothing when there is no window to present from, which
    /// only happens with no scene in the foreground.
    static func present(_ url: URL) {
        guard let top = topViewController() else { return }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        top.present(sheet, animated: true)
    }

    /// The controller everything else is under: the key window's root, followed up through whatever
    /// it presents. A controller already on its way out is not one to present from.
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
