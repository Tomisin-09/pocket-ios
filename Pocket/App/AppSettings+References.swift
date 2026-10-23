import Foundation

/// The References library's layout (ADR 0275): how it groups its sources, and which sections are folded.
extension AppSettings {

    /// What the library opens on until the player picks another: *Newest*, the library as it was before
    /// grouping existed, so an upgrading install sees no change. Named for the reason `homeToolDefault`
    /// is: an `@AppStorage` default is what SwiftUI uses for an unset key, so the screen binds to this
    /// rather than to a literal of its own.
    static let referencesGroupingDefault = ReferenceGrouping.newest

    /// Clear both keys, beside `resetHomeTool` and for its reason: called once at launch under
    /// `-uiTesting` and nowhere else, so a test that groups the library by site doesn't leave it grouped
    /// for the next test, the next run, or the library figure the manual is shot through.
    static func resetReferencesLayout(store: UserDefaults = .standard) {
        store.removeObject(forKey: Key.referencesGrouping)
        store.removeObject(forKey: Key.referencesCollapsedSections)
    }
}
