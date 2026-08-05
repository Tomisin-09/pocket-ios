import XCTest
@testable import Pocket

/// `SessionUnitRef` — the **loose id copies** a session journal entry snapshots (ADR 0143).
///
/// This is the one piece of the slice that is stored as hand-rolled JSON rather than as columns, so
/// the round-trip is asserted rather than assumed. The failure that matters most is the ugly one:
/// a payload that won't parse must degrade to "no units listed", **never** throw or trap. It sits
/// inside a `@Model`'s computed accessor, on the Journal feed's render path — a trap there takes the
/// whole timeline down, and a stored string is exactly the field a future schema change can leave
/// half-written.
final class SessionUnitRefTests: XCTestCase {

    // MARK: - Round trip

    func testEncodeDecodeRoundTripPreservesEveryField() {
        let refs = [SessionUnitRef(uid: UUID(), title: "Alternating picking", kind: .exercise),
                    SessionUnitRef(uid: UUID(), title: "Little Wing · Verse riff", kind: .loop)]

        let decoded = SessionUnitRef.decode(SessionUnitRef.encode(refs))

        XCTAssertEqual(decoded, refs, "uid, title and kind all survive, in order")
    }

    func testEmptyListEncodesToNilRatherThanAnEmptyArrayLiteral() {
        XCTAssertNil(SessionUnitRef.encode([]),
                     "\"no units\" and \"never written\" should read the same way in the column")
    }

    // MARK: - Tolerance

    func testMalformedPayloadDecodesToNoUnits() {
        XCTAssertEqual(SessionUnitRef.decode("{ not json at all"), [])
        XCTAssertEqual(SessionUnitRef.decode("[{\"uid\":\"not-a-uuid\"}]"), [])
        XCTAssertEqual(SessionUnitRef.decode(""), [])
    }

    func testNilPayloadDecodesToNoUnits() {
        XCTAssertEqual(SessionUnitRef.decode(nil), [],
                       "every unit-owned entry reads this field; it must cost nothing and never fail")
    }

    func testAnUnrecognisedKindDecodesButResolvesToNothing() {
        let ref = SessionUnitRef(uid: UUID(), title: "Something new", kindRaw: "song")
        let decoded = SessionUnitRef.decode(SessionUnitRef.encode([ref]))

        XCTAssertEqual(decoded.first?.title, "Something new", "the ref itself still round-trips")
        XCTAssertNil(decoded.first?.kind, "…but names a kind this version can't act on")
        XCTAssertNil(JournalOwnerRoute.route(for: ref, exercises: [], loops: []),
                     "an unknown kind is a pill with nowhere to go, not a crash")
    }

    // MARK: - The accessor on the entry

    func testAnEntryReadsBackTheUnitsItWasWrittenWith() {
        let units = [SessionUnitRef(uid: UUID(), title: "Spider", kind: .exercise)]
        let entry = JournalEntry.forSession(text: "shoulders tight today", kind: .session,
                                            routineUID: UUID(), routineName: "Morning warm-up",
                                            units: units)

        XCTAssertEqual(entry.practisedUnits, units)
    }

    func testAUnitOwnedEntryHasNoPractisedUnits() {
        let entry = JournalEntry.forExercise(text: "held 96 clean", kind: .breakthrough,
                                             commandBpmAtEntry: 96)

        XCTAssertEqual(entry.practisedUnits, [])
        XCTAssertNil(entry.practisedUnitsRaw)
    }
}
