import Foundation

// The data the views show. Plain values: the app maps whatever it has —
// a database row, a network object, a CRDT — into these, and keeps them
// current. Nothing here knows how a message travels.

/// One message in a thread.
public struct MessageItem: Identifiable, Hashable, Sendable {
    public var id: String
    public var isMine: Bool
    public var content: MessageContent
    public var timestamp: Date
    /// Reactions under the bubble, in the order the app folds them.
    public var reactions: [Reaction] = []

    public init(id: String, isMine: Bool, content: MessageContent, timestamp: Date) {
        self.id = id
        self.isMine = isMine
        self.content = content
        self.timestamp = timestamp
    }

    public init(id: String, isMine: Bool, text: String, timestamp: Date) {
        self.init(id: id, isMine: isMine, content: .text(text), timestamp: timestamp)
    }
}
