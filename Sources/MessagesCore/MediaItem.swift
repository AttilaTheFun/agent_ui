import Foundation
// For CGFloat: on Apple it is CoreGraphics', reached through SwiftUI; on the
// portable SwiftUI it is the SwiftUI module's own.
import SwiftUI

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
