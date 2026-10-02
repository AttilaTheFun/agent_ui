import Foundation

/// One inbox row.
public struct ConversationSummary: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var avatar: AvatarSource
    public var presence: Presence
    /// The last line of the conversation, or what to say when there is none.
    public var preview: String
    /// When the last message arrived; nothing shows no time.
    public var timestamp: Date?

    public init(id: String, name: String, avatar: AvatarSource? = nil, presence: Presence = .hidden,
                preview: String = "", timestamp: Date? = nil) {
        self.id = id
        self.name = name
        self.avatar = avatar ?? .initial(name)
        self.presence = presence
        self.preview = preview
        self.timestamp = timestamp
    }
}
