import Foundation

/// Pure neighbour-finding for the transport's previous / next skip (pocket-040,
/// ADR 0030). Given an ordered list of ids and the current one, return the id
/// before or after it. UI-free so the skip logic is unit-testable without an
/// engine or a SwiftData context.
enum TransportNav {

    /// The id immediately before `current` in `order`, or `nil` when `current`
    /// is the first element or isn't present.
    static func previous<ID: Equatable>(before current: ID?, in order: [ID]) -> ID? {
        guard let current, let index = order.firstIndex(of: current), index > 0 else { return nil }
        return order[index - 1]
    }

    /// The id immediately after `current` in `order`, or `nil` when `current`
    /// is the last element or isn't present.
    static func next<ID: Equatable>(after current: ID?, in order: [ID]) -> ID? {
        guard let current, let index = order.firstIndex(of: current),
              index < order.count - 1 else { return nil }
        return order[index + 1]
    }
}
