import SwiftUI

/// A message's markdown as a preview's one text, an inbox's or a list's
/// row: MarkdownText's own reading of it, its inline styles as the thread
/// shows them (bold, italic, `code`), and its blocks flattened to their
/// words, a line each — a heading's, each list item's without its marker,
/// a quote's, a table's cells, a code block's lines in the monospaced
/// font — so a line limit cuts it as it would any text. A link is its
/// words, plain, with nothing to follow: a row is tapped whole. Its font,
/// color and line limit are the caller's.
public struct MarkdownPreview: View {
    let text: String

    public init(_ text: String) { self.text = text }

    public var body: some View {
        let blocks = MarkdownCache.blocks(text)
        return MarkdownCache.preview(text) { _ in Self.preview(blocks) }
    }

    /// One line of the preview: inline markdown, or a code block's line.
    enum Piece: Equatable {
        case inline(String)
        case code(String)

        var words: String {
            switch self {
            case .inline(let words), .code(let words): return words
            }
        }
    }

    /// The blocks' lines, in order: what a preview shows of each.
    static func pieces(_ blocks: [MarkdownBlock]) -> [Piece] {
        var pieces: [Piece] = []
        for block in blocks {
            switch block {
            case .paragraph(let lines): pieces += lines.split(separator: "\n").map { .inline(String($0)) }
            case .heading(_, let line): pieces.append(.inline(line))
            case .list(let items): pieces += items.map { .inline($0.text) }
            case .code(let code, _): pieces += code.split(separator: "\n").map { .code(String($0)) }
            case .table(let header, let rows):
                pieces += ([header] + rows).map { .inline($0.filter { !$0.isEmpty }.joined(separator: "  ")) }
            case .quote(let quoted): pieces += Self.pieces(MarkdownBlocks.split(quoted))
            }
        }
        return pieces.filter { !$0.words.trimmingWhitespace().isEmpty }
    }

    private static func preview(_ blocks: [MarkdownBlock]) -> Text {
        var result: Text?
        for piece in pieces(blocks) {
            let line: Text
            switch piece {
            case .inline(let words): line = MarkdownText.styled(words, links: false)
            case .code(let code): line = Text(code).monospaced()
            }
            result = result.map { $0 + Text("\n") + line } ?? line
        }
        return result ?? Text("")
    }
}
