import SwiftUI

public struct TranscriptMessage: Identifiable, Equatable, Sendable {
    public enum Role: Equatable, Sendable { case user, assistant, tool }

    public var id: String
    public var role: Role
    public var text: String
    /// An assistant turn's tool calls, as activity labels ("Building").
    public var activities: [String]
    /// A tool result's tool name (build / crash / import / web_search / …).
    public var toolName: String?
    /// Images to show with the message (URLs the platform's image loader displays).
    public var imageURLs: [String]
    /// Each image's size in pixels, by position in `imageURLs`, when the
    /// app knows it before the bytes arrive: the row is then laid out at
    /// its final size from the first frame instead of reshaping itself
    /// as each picture lands. Nil where unknown.
    public var imageSizes: [CGSize?]

    public init(id: String, role: Role, text: String, activities: [String] = [], toolName: String? = nil,
                imageURLs: [String] = [], imageSizes: [CGSize?] = []) {
        self.id = id
        self.role = role
        self.text = text
        self.activities = activities
        self.toolName = toolName
        self.imageURLs = imageURLs
        self.imageSizes = imageSizes
    }
}
