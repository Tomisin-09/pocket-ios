import Foundation
import os
import OSLog
import SwiftData

/// The store's logger: what `saveOrLog()` writes when a save fails.
enum StoreLog {
    static let log = Logger(subsystem: "click.decooperations.pocket", category: "store")
}

extension ModelContext {
    /// Save, and if it fails, say so in the device's log instead of throwing the error away.
    ///
    /// Until 1.6.1 nearly every save in the app was `try? context.save()`. If one failed (a full disk is
    /// the likely way), the change stayed on screen, was gone after the next launch, and nothing anywhere
    /// recorded it. This is the one way to save that carries on after a failure. It logs the error under
    /// the `store` category, with the file and line that saved, and returns whether the save worked. A
    /// caller with something to do on failure reads the result. The rest ignore it, as they ignored the
    /// error before, so swapping it in changes nothing a player sees.
    ///
    /// It only logs. Nothing leaves the device (ADR 0239). The error's domain and code are logged in the
    /// clear, so a sysdiagnose says what failed. Its description is marked private, because a SwiftData
    /// error can quote a model's values, and those are the player's.
    ///
    /// `.swiftlint.yml`'s `save_error_discarded` rule bans `try? ….save()`, so this stays the only way.
    @discardableResult
    func saveOrLog(fileID: StaticString = #fileID, line: UInt = #line) -> Bool {
        do {
            #if DEBUG
            if SaveFailureDrill.fails(in: "\(fileID)") { throw SaveFailureDrill.Failure() }
            #endif
            try save()
            return true
        } catch {
            let site = "\(fileID):\(line)"
            let nsError = error as NSError
            StoreLog.log.error("""
                Save failed at \(site, privacy: .public): \(nsError.domain, privacy: .public) \
                \(nsError.code, privacy: .public): \(nsError.localizedDescription, privacy: .private)
                """)
            return false
        }
    }
}

#if DEBUG
/// `-failSaveIn` (ADR 0318): the first save from the file a UI test names fails, once, so the test can
/// see *Couldn’t save* and then watch *Try again* work. Debug builds only, and only under `-uiTesting`
/// (`UITestRuntime.failingSaveFile`), so no build a player holds can fail a save on purpose.
enum SaveFailureDrill {
    struct Failure: Error {}

    private static let pending = OSAllocatedUnfairLock<String?>(initialState: UITestRuntime.failingSaveFile)

    /// Whether this save should fail. True once, for the named file, then never again.
    static func fails(in fileID: String) -> Bool {
        pending.withLock { file in
            guard file == fileID else { return false }
            file = nil
            return true
        }
    }
}
#endif
