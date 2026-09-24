import Foundation
// For CGFloat: on Apple it is CoreGraphics', reached through SwiftUI; on the
// portable SwiftUI it is the SwiftUI module's own.
import SwiftUI

// The data the views show. Plain values: the app maps whatever it has —
// a database row, a network object, a CRDT — into these, and keeps them
// current. Nothing here knows how a message travels.

/// Whether the other party is reachable, for the dot on their avatar.
public enum Presence: Hashable, Sendable {
    case online
    case idle
    case offline
    /// No dot at all (a group, a draft, an unknown).
    case hidden
}

/// What to draw in an avatar's circle.
public enum AvatarSource: Hashable, Sendable {
    /// The first letter of a name.
    case initial(String)
    /// An SF Symbol (the "person.fill" of a new conversation).
    case symbol(String)
    /// A picture.
    case image(URL)
}

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

/// A picture or a clip in a message.
public struct MediaItem: Hashable, Sendable {
    public var url: URL
    /// Width over height, so the bubble can be laid out before the bytes load.
    public var aspectRatio: CGFloat
    /// For a video: a still to show until it plays.
    public var poster: URL?

    public init(url: URL, aspectRatio: CGFloat = 4 / 3, poster: URL? = nil) {
        self.url = url
        self.aspectRatio = aspectRatio
        self.poster = poster
    }
}

/// What a message carries. Text is the common case; media renders in
/// bubbles of its own; `custom` is anything else, drawn by a renderer the
/// app supplies (`messageContentRenderer`).
public enum MessageContent: Hashable, Sendable {
    case text(String)
    case image(MediaItem)
    case video(MediaItem)
    case album([MediaItem])
    /// An app-defined kind with an opaque payload (JSON, an id, anything).
    case custom(kind: String, payload: String)
}

/// One emoji's reactions on a message, folded: how many, and whether ours
/// is among them.
public struct Reaction: Hashable, Sendable {
    public var emoji: String
    public var count: Int
    public var mine: Bool

    public init(emoji: String, count: Int, mine: Bool) {
        self.emoji = emoji
        self.count = count
        self.mine = mine
    }
}

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

/// The inbox's time column, as Messages writes it: the time today, the
/// weekday this week, the date before that. Assembled from calendar
/// components, not a DateFormatter, which not every Foundation has (the
/// lightweight one on wasm and Android has Calendar, in UTC).
public enum MessagesTime {
    public static func label(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: date)
        guard let hour = parts.hour, let minute = parts.minute, let year = parts.year,
              let month = parts.month, let day = parts.day, let weekday = parts.weekday else { return "" }
        if calendar.isDate(date, inSameDayAs: now) {
            let h12 = hour % 12 == 0 ? 12 : hour % 12
            return "\(h12):\(minute < 10 ? "0" : "")\(minute) \(hour < 12 ? "AM" : "PM")"
        }
        if let week = calendar.date(byAdding: .day, value: -6, to: now), date > week {
            let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            return names[(weekday - 1 + 7) % 7]
        }
        return "\(month)/\(day)/\(year % 100 < 10 ? "0" : "")\(year % 100)"
    }
}
