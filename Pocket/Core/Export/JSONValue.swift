import Foundation

/// A faithful, schema-free representation of any JSON value.
///
/// Three of the app's models keep already-encoded JSON in an opaque column — `Exercise.templatePayload`
/// and `SavedChord.voicingData` as `Data`, `JournalEntry.practisedUnitsRaw` as a `String`. Emitting
/// those as base64 would make the archive unreadable for exactly the fields a person opening it is
/// most likely to want to read, so each one is decoded into this and nested as real JSON.
///
/// Deliberately **untyped**. Switching on the owning model's `kind` to pick `StrumPattern` /
/// `FretboardContent` / `ChordProgression` / `StrumChordSheet` (`Exercise+Template.swift`) would freeze
/// today's four template types into the exporter, and a payload written by a newer build would drop out
/// of the archive entirely. Round-tripping the JSON verbatim keeps a blob *this* version cannot
/// interpret intact for one that can — the same forward-compatibility the decoders themselves aim for.
enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case integer(Int)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    // MARK: - Decoding

    /// Order matters. `Bool` is tried before `Int` because Foundation decodes JSON `true` into an
    /// integer on some platforms, and `Int` before `Double` so a whole number survives the round trip
    /// as `4` rather than `4.0` — cosmetic in the file, but it is the difference between an archive
    /// that reads like the app's own data and one that reads like a float dump.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Unrecognised JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case let .bool(value): try container.encode(value)
        case let .integer(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        }
    }

    // MARK: - Reading the app's opaque columns

    /// Decode a stored blob, or `nil` when there is nothing to read or it cannot be parsed.
    ///
    /// **Never throws.** A payload an older build wrote in a shape this one cannot parse must cost the
    /// archive that one field, not the whole export — the same degrade-don't-fail rule
    /// `SessionUnitRef.decode` and `Exercise.strumPattern` already follow.
    static func decoding(_ data: Data?) -> JSONValue? {
        guard let data, !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(JSONValue.self, from: data)
    }

    /// Decode a stored blob held as a `String` rather than `Data` — `JournalEntry.practisedUnitsRaw`
    /// is JSON in a text column, because SwiftData will not take a `Codable` attribute.
    static func decoding(json: String?) -> JSONValue? {
        guard let json, !json.isEmpty else { return nil }
        return decoding(Data(json.utf8))
    }
}
