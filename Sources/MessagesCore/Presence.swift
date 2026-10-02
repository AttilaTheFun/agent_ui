/// Whether the other party is reachable, for the dot on their avatar.
public enum Presence: Hashable, Sendable {
    case online
    case idle
    case offline
    /// No dot at all (a group, a draft, an unknown).
    case hidden
}
