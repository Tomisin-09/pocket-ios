import AVFoundation
import XCTest
@testable import Pocket

/// Route classification for practice-take isolation (ADR 0069 §2). This is the pure logic
/// behind the headphone-clean vs speaker-bleed cue — it decides whether a take captures only
/// the guitar or the backing track too, so it's pinned here (AGENTS.md: UI-free logic must
/// be unit-tested).
final class RecordingRouteTests: XCTestCase {

    // MARK: clean (private listening — loop not in the room)

    func testHeadphonesAreClean() {
        XCTAssertEqual(RecordingRoute.classify(outputs: [.headphones]), .cleanIsolated)
    }

    func testBluetoothA2DPIsClean() {
        XCTAssertEqual(RecordingRoute.classify(outputs: [.bluetoothA2DP]), .cleanIsolated)
    }

    func testWiredAndUSBInterfacesAreClean() {
        XCTAssertEqual(RecordingRoute.classify(outputs: [.lineOut]), .cleanIsolated)
        XCTAssertEqual(RecordingRoute.classify(outputs: [.usbAudio]), .cleanIsolated)
    }

    // MARK: bleed (speaker in the room, or unknown → warn)

    func testBuiltInSpeakerIsBleed() {
        XCTAssertEqual(RecordingRoute.classify(outputs: [.builtInSpeaker]), .speakerBleed)
    }

    func testAirPlayAndCarAudioAreBleed() {
        // Could be room speakers / HomePod / car cabin — can't promise isolation, so warn.
        XCTAssertEqual(RecordingRoute.classify(outputs: [.airPlay]), .speakerBleed)
        XCTAssertEqual(RecordingRoute.classify(outputs: [.carAudio]), .speakerBleed)
    }

    func testEmptyRouteIsBleed() {
        // Unknown route → warn rather than promise a clean take.
        XCTAssertEqual(RecordingRoute.classify(outputs: []), .speakerBleed)
    }

    // MARK: mixed routes — any speaker output taints the whole take

    func testMixedHeadphonesPlusSpeakerIsBleed() {
        XCTAssertEqual(RecordingRoute.classify(outputs: [.headphones, .builtInSpeaker]),
                       .speakerBleed)
    }

    // MARK: derived cue

    func testCleanRouteHasNoNudgeAndIsClean() {
        let route = RecordingRoute.cleanIsolated
        XCTAssertTrue(route.isClean)
        XCTAssertNil(route.nudge)
    }

    func testBleedRouteNudgesAndIsNotClean() {
        let route = RecordingRoute.speakerBleed
        XCTAssertFalse(route.isClean)
        XCTAssertNotNil(route.nudge)
    }
}
