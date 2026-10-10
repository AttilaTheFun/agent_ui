import SwiftUI

/// A message's markdown, as SwiftUI text: paragraphs with inline styles
/// (bold, italic, code, links), fenced code as a monospaced block, headings
/// bold, bullet and numbered lines with their markers, quotes set off by a
/// bar. Apple's SwiftUI has
/// `AttributedString(markdown:)`; the portable one shows the text as is.
public struct MarkdownText: View {
    let text: String

    public init(_ text: String) { self.text = text }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(MarkdownBlocks.split(text).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        // On every block, not only the ones that ask: a paragraph, a
        // heading and a list item are all worth selecting a line out of.
        .textSelection(.enabled)
    }

    @ViewBuilder private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .code(let code, _):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .padding(10)
            }
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(8)
        case .heading(let level, let line):
            inline(line)
                .font(level <= 1 ? .title3.bold() : (level == 2 ? .headline : .subheadline.bold()))
        case .list(let items):
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text(item.marker).foregroundColor(.secondary)
                        // As tall as its lines: beside the marker, in a
                        // list cell, the item was otherwise given one
                        // line and stopped at "…".
                        inline(item.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        case .paragraph(let lines):
            inline(lines)
        case .table(let header, let rows):
            MarkdownTable(header: header, rows: rows, inline: inline)
        case .quote(let quoted):
            // Its own markdown, in the secondary colour, beside a bar as
            // tall as it is.
            MarkdownText(quoted)
                .foregroundColor(.secondary)
                .padding(.leading, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 3)
                }
        }
    }

    /// Inline markdown as text. Links are gray, semibold and underlined
    /// rather than the accent colour. Apple's SwiftUI parses it as an
    /// AttributedString; the portable one gets styled `Text` runs from a
    /// small parser of the same inline syntax.
    private func inline(_ text: String) -> Text {
        #if canImport(UIKit) || canImport(AppKit)
        if var attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            for run in attributed.runs where run.link != nil {
                attributed[run.range].foregroundColor = .secondary
                attributed[run.range].underlineStyle = .single
                attributed[run.range].font = .body.weight(.semibold)
            }
            return Text(attributed)
        }
        return Text(text)
        #else
        return InlineMarkdown.text(text)
        #endif
    }
}
