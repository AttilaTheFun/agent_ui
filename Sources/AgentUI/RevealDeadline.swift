/// When a thread's first rows are drawn at the latest, whatever its
/// settling does. Each settle starts its moment again, and the rows were
/// drawn only when one ran its course: on a slow device something settled
/// again faster than that, and the thread stayed hidden under its empty
/// state for as long as anyone watched (Apple's iOS 27.2 simulator under
/// Darling, 20 s and more). The first settle arms the deadline; later ones
/// leave it where it is, so the rows are drawn `limit` after the first
/// however often the thread settles again. A thread that settles sooner is
/// drawn sooner, as before: the deadline only bounds it.
///
/// Times are given, not read, so the steps can be tested without waiting.
struct RevealDeadline {
    /// How long after the first settle the rows are drawn at the latest:
    /// several of today's settles (300 ms), and short enough to read as
    /// the thread opening slowly rather than not at all.
    static let limit: Duration = .milliseconds(1500)

    /// When the first settle came, while the rows are still hidden.
    private(set) var armed: ContinuousClock.Instant?
    /// How many settles have come since the first, it included.
    private(set) var settles = 0
    /// The rows are drawn: nothing more is armed.
    private(set) var done = false

    /// A settle at `now`: the first arms the deadline. How long until the
    /// rows are due (zero once overdue), or nil once they are drawn.
    mutating func settle(at now: ContinuousClock.Instant) -> Duration? {
        guard !done else { return nil }
        if armed == nil { armed = now }
        settles += 1
        return remaining(at: now)
    }

    /// How long until the rows are due at `now` (zero once overdue), or nil
    /// when nothing is armed.
    func remaining(at now: ContinuousClock.Instant) -> Duration? {
        guard !done, let armed else { return nil }
        return max(.zero, armed + Self.limit - now)
    }

    /// Whether the rows are overdue at `now`.
    func isDue(at now: ContinuousClock.Instant) -> Bool {
        remaining(at: now) == .zero
    }

    /// The rows are drawn, by the deadline or sooner.
    mutating func revealed() {
        done = true
        armed = nil
    }

    /// Whole milliseconds, for the log.
    static func milliseconds(_ duration: Duration) -> Int {
        let parts = duration.components
        return Int(parts.seconds) * 1000 + Int(parts.attoseconds / 1_000_000_000_000_000)
    }
}
