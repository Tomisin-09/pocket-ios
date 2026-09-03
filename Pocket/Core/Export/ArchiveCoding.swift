import Foundation

/// How every file this app writes spells a date, and the encoder/decoder pair that does it
/// (ADR 0181, ADR 0188).
///
/// Split out of `ArchiveBuilder` the moment a second root type arrived. `practice.json` inside an
/// exported archive and a shared `.redmoonpractice` file are different payloads that have to agree
/// exactly about formatting — the same sorted keys, the same fractional-seconds timestamps — because
/// one reader parses both. Two copies of that configuration would be two chances to drift, and the
/// drift would show up as dates that move on the way back in rather than as a compile error.
///
/// Nothing here touches a model or the main actor, so it runs wherever the caller is — which for an
/// export of any size should not be the main thread.
enum ArchiveCoding {

    /// ISO-8601 **including fractional seconds**.
    ///
    /// Foundation's built-in `.iso8601` strategy truncates to the second, which silently moves every
    /// date in a file by up to a second on the way back in — caught by the round-trip test, which
    /// failed against two values that printed identically. A backup that cannot reproduce its own
    /// timestamps is not one, so the format carries milliseconds.
    ///
    /// `Date.ISO8601FormatStyle` rather than `ISO8601DateFormatter`: it is a `Sendable` value type,
    /// and the strategy closures below are `@Sendable` under Swift 6 — capturing a class-based
    /// formatter in one compiles locally and fails on CI's stricter toolchain.
    static var dateStyle: Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    }

    /// Encode a payload.
    ///
    /// Sorted keys and readable dates, both so the output is stable and legible: a person opening
    /// `practice.json` gets dates they can read rather than seconds since 2001, and a diff between
    /// two files shows what changed rather than what the encoder felt like ordering differently.
    static func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(dateStyle))
        }
        return try encoder.encode(value)
    }

    /// Read one back.
    ///
    /// Falls back to whole-second ISO-8601 so a hand-edited file, or one written before fractional
    /// seconds were carried, still parses rather than failing the whole payload over a timestamp.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(text, strategy: dateStyle) { return date }
            return try Date(text, strategy: Date.ISO8601FormatStyle())
        }
        return try decoder.decode(type, from: data)
    }
}
