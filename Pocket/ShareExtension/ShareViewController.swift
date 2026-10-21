import SwiftUI
import UIKit

/// **The share extension's principal class** (ADR 0264 D8), named by its `Info.plist`. It reads the
/// owner snapshot, loads what was shared, and hosts `SaveToRedMoonView`. It never opens the store (D9).
final class ShareViewController: UIViewController {
    private var model: ShareSaveModel?

    override func viewDidLoad() {
        super.viewDidLoad()
        let directory = ShareContainer.directory()
        let model = ShareSaveModel(snapshot: directory.flatMap(ShareOwnerSnapshot.read(from:)))
        self.model = model

        let host = UIHostingController(rootView: SaveToRedMoonView(
            model: model,
            onCancel: { [weak self] in self?.cancel() },
            onSave: { [weak self] in self?.save(into: directory) }
        ))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        Task { await model.load(items) }
    }

    private func save(into directory: URL?) {
        guard let model, model.save(into: directory) else { return }
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }
}
