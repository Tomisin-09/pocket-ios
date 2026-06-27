import Foundation

/// Holds a security-scoped resource open for its lifetime, releasing it on dealloc.
/// Lets a `@MainActor` owner release access implicitly via property teardown, with
/// no nonisolated `deinit` reaching into actor-isolated state (Swift 6).
///
/// Shared by the practice surfaces that resolve an imported song's bookmark and hand
/// the URL to `PracticeAudioEngine` for lazy reads — the waveform screen
/// (`WaveformPracticeModel`) and the Practice loop run (`LoopRunModel`, ADR 0046 Phase B).
final class SecurityScopedAccess {
    private let url: URL
    init?(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        self.url = url
    }
    deinit { url.stopAccessingSecurityScopedResource() }
}
