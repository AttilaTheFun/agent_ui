/// Where the reader is in a transcript (AgentView's `viewport`): the first
/// message on screen, and whether the thread follows its end. Told once the
/// reader has stopped (not while scrolling or typing), so the app may let go
/// of rows far above it and load them again if the reader comes back.
public struct TranscriptViewport: Equatable, Sendable {
    /// The first message on screen, by its id; nil while none is.
    public var topID: String?
    /// The thread is at its end, taking new rows as they come.
    public var followingEnd: Bool

    public init(topID: String?, followingEnd: Bool) {
        self.topID = topID
        self.followingEnd = followingEnd
    }
}
