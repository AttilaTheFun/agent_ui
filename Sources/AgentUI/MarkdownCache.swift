import SwiftUI

/// Parsed markdown kept by its text: a thread's rows are drawn again and
/// again with the same words, and parsing them on each pass (the blocks,
/// then each block's inline styles) was a cost of every pass on a long
/// thread — on Isomer about a millisecond a message, interpreted. Bounded:
/// past `limit` texts it starts over.
@MainActor
enum MarkdownCache {
    static let limit = 2000
    private static var blocks: [String: [MarkdownBlock]] = [:]
    private static var inline: [String: Text] = [:]

    /// The text's blocks, split once.
    static func blocks(_ text: String) -> [MarkdownBlock] {
        if let kept = blocks[text] { return kept }
        let split = MarkdownBlocks.split(text)
        if blocks.count >= limit { blocks.removeAll(keepingCapacity: true) }
        blocks[text] = split
        return split
    }

    /// The text's inline styles as `Text`, made once by `make`.
    static func inline(_ text: String, make: (String) -> Text) -> Text {
        if let kept = inline[text] { return kept }
        let made = make(text)
        if inline.count >= limit { inline.removeAll(keepingCapacity: true) }
        inline[text] = made
        return made
    }
}
