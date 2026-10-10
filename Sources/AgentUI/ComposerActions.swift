import Observation

/// What the composer's field and send button call: one instance the
/// composer keeps, its callbacks set on each of the composer's passes. Held
/// rather than given as closures, the field and the button compare equal
/// across those passes when nothing they show changed (a closure never
/// does), and are not evaluated again.
@MainActor
@Observable
final class ComposerActions {
    /// Sends the words as the caller has them.
    @ObservationIgnored var send: (String) -> Void = { _ in }
    /// Sends them now, cutting the agent's turn short (nil: not offered).
    @ObservationIgnored var steer: ((String) -> Void)?
    @ObservationIgnored var stop: () -> Void = {}
    /// Starts or stops dictation (nil: none here).
    @ObservationIgnored var dictate: (() -> Void)?
    /// The draft changed after a hand-over: cleared, or kept.
    @ObservationIgnored var settle: (_ cleared: Bool) -> Void = { _ in }
}
