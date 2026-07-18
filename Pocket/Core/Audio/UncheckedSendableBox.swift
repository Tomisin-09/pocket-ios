/// Carries a non-`Sendable` value across an actor boundary when the caller guarantees single-threaded
/// use — e.g. opening an `AVAudioFile` off the main actor, then touching it main-actor-only thereafter.
/// A deliberate, localised `@unchecked Sendable` escape hatch, not a general-purpose wrapper: only use
/// it where the hand-off discipline is obvious at the call site.
struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
