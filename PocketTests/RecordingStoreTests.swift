import XCTest
@testable import Pocket

/// Pure derivations + retention sweep for practice-take storage (ADR 0069 §5). The `FileManager`
/// wrappers (directory/delete/size) are thin I/O and exercised on device; the *logic* that must not
/// break silently — the filename identity and which files are safe to reap — is pinned here
/// (AGENTS.md: pure logic must be unit-tested).
final class RecordingStoreTests: XCTestCase {

    func testFileNameIsUidWithM4AExtension() {
        let uid = UUID()
        XCTAssertEqual(RecordingStore.fileName(for: uid), "\(uid.uuidString).m4a")
    }

    func testOrphanedFilesAreThoseNotReferenced() {
        let onDisk = ["a.m4a", "b.m4a", "c.m4a"]
        let referenced: Set<String> = ["a.m4a", "c.m4a"]
        XCTAssertEqual(RecordingStore.orphanedFiles(onDisk: onDisk, referenced: referenced),
                       ["b.m4a"], "only the unreferenced file is reapable")
    }

    func testNoOrphansWhenEveryFileIsReferenced() {
        let onDisk = ["a.m4a", "b.m4a"]
        XCTAssertTrue(RecordingStore.orphanedFiles(onDisk: onDisk,
                                                   referenced: ["a.m4a", "b.m4a"]).isEmpty)
    }

    func testAllFilesOrphanedWhenNothingReferenced() {
        let onDisk = ["a.m4a", "b.m4a"]
        XCTAssertEqual(RecordingStore.orphanedFiles(onDisk: onDisk, referenced: []), onDisk,
                       "a store with no surviving takes reaps every file")
    }

    func testReferencedFileMissingFromDiskIsNotAnOrphan() {
        // A model pointing at a file that isn't there yet (e.g. mid-write) never appears as an
        // orphan — the sweep only ever proposes deleting real, unreferenced files.
        XCTAssertTrue(RecordingStore.orphanedFiles(onDisk: [], referenced: ["ghost.m4a"]).isEmpty)
    }
}
