import SwiftUI

/// A message's markdown, as SwiftUI text: paragraphs with inline styles
/// (bold, italic, code, links), fenced code as a monospaced block, headings
/// bold, bullet and numbered lines with their markers. Apple's SwiftUI has
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
                        inline(item.text)
                    }
                }
            }
        case .paragraph(let lines):
            inline(lines)
        case .table(let header, let rows):
            MarkdownTable(header: header, rows: rows, inline: inline)
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

/// Inline markdown → concatenated styled `Text`: **bold**, *italic* or
/// _italic_, `code`, [title](url), ~~strike~~. Unbalanced markers stay as text.
enum InlineMarkdown {
    struct Span { var text: String; var bold = false; var italic = false; var code = false; var link = false; var strike = false }

    static func text(_ markdown: String) -> Text {
        let spans = parse(markdown)
        var result: Text? = nil
        for span in spans {
            var piece = Text(span.text)
            if span.bold { piece = piece.bold() }
            if span.italic { piece = piece.italic() }
            if span.code { piece = piece.monospaced() }
            if span.strike { piece = piece.strikethrough() }
            if span.link { piece = piece.underline().bold().foregroundColor(.secondary) }
            result = result.map { $0 + piece } ?? piece
        }
        return result ?? Text("")
    }

    static func parse(_ markdown: String) -> [Span] {
        var spans: [Span] = []
        var current = Span(text: "")
        var bold = false, italic = false, strike = false
        let chars = Array(markdown)
        var i = 0
        func flush() { if !current.text.isEmpty { spans.append(current) }; current = Span(text: "", bold: bold, italic: italic, strike: strike) }
        while i < chars.count {
            let c = chars[i]
            let next = i + 1 < chars.count ? chars[i + 1] : nil
            if c == "`" {
                // Code: up to the closing backtick on the same line.
                if let close = chars[(i + 1)...].firstIndex(of: "`") {
                    flush()
                    spans.append(Span(text: String(chars[(i + 1)..<close]), code: true))
                    i = close + 1
                    continue
                }
            }
            if c == "[" , let closeBracket = chars[i...].firstIndex(of: "]"), closeBracket + 1 < chars.count, chars[closeBracket + 1] == "(",
               let closeParen = chars[(closeBracket + 1)...].firstIndex(of: ")") {
                flush()
                spans.append(Span(text: String(chars[(i + 1)..<closeBracket]), link: true))
                i = closeParen + 1
                continue
            }
            if c == "*" && next == "*" || c == "_" && next == "_" {
                flush(); bold.toggle(); current.bold = bold; i += 2; continue
            }
            if c == "~" && next == "~" {
                flush(); strike.toggle(); current.strike = strike; i += 2; continue
            }
            if (c == "*" || c == "_") && (i == 0 || !chars[i - 1].isLetter || italic) && (next == nil || !next!.isWhitespace || italic) {
                flush(); italic.toggle(); current.italic = italic; i += 1; continue
            }
            current.text.append(c)
            i += 1
        }
        flush()
        return spans
    }
}

/// A markdown table: a bold header row, hairlines between rows, columns
/// sharing the width. Long tables scroll sideways rather than squeeze.
struct MarkdownTable: View {
    let header: [String]
    let rows: [[String]]
    let inline: (String) -> Text

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                row(header, bold: true)
                Rectangle().fill(Color.secondary.opacity(0.4)).frame(height: 1)
                ForEach(Array(rows.enumerated()), id: \.offset) { index, cells in
                    row(cells, bold: false)
                    if index < rows.count - 1 {
                        Rectangle().fill(Color.secondary.opacity(0.15)).frame(height: 1)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func row(_ cells: [String], bold: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                inline(cell)
                    .font(bold ? .subheadline.weight(.semibold) : .subheadline)
                    .frame(minWidth: 60, alignment: .leading)
            }
        }
        .padding(.vertical, 5)
    }
}

enum MarkdownBlock {
    case paragraph(String)
    case heading(Int, String)
    case code(String, language: String)
    case list([(marker: String, text: String)])
    case table(header: [String], rows: [[String]])
}

enum MarkdownBlocks {
    /// Splits markdown into blocks: fenced code, headings, lists, paragraphs.
    static func split(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var list: [(String, String)] = []
        var code: [String]? = nil
        var language = ""
        var table: [[String]] = []

        func flushParagraph() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
        }
        func flushList() {
            if !list.isEmpty { blocks.append(.list(list.map { (marker: $0.0, text: $0.1) })); list = [] }
        }
        func flushTable() {
            // A header, a separator (|---|---|) and the rows; the separator is dropped.
            if table.count >= 2, table[1].allSatisfy({ $0.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " } }) {
                blocks.append(.table(header: table[0], rows: Array(table.dropFirst(2))))
            } else if !table.isEmpty {
                blocks.append(.paragraph(table.map { "| " + $0.joined(separator: " | ") + " |" }.joined(separator: "\n")))
            }
            table = []
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if var openCode = code {
                if line.trimmingWhitespace().hasPrefix("```") {
                    blocks.append(.code(openCode.joined(separator: "\n"), language: language))
                    code = nil
                } else {
                    openCode.append(line)
                    code = openCode
                }
                continue
            }
            let trimmed = line.trimmingWhitespace()
            if trimmed.hasPrefix("```") {
                flushParagraph(); flushList(); flushTable()
                code = []
                language = String(trimmed.dropFirst(3))
                continue
            }
            if trimmed.hasPrefix("|") {
                flushParagraph(); flushList()
                var inner = Substring(trimmed.dropFirst())
                if inner.hasSuffix("|") { inner = inner.dropLast() }
                table.append(inner.split(separator: "|", omittingEmptySubsequences: false).map { String($0).trimmingWhitespace() })
                continue
            }
            flushTable()
            if trimmed.isEmpty {
                flushParagraph(); flushList()
                continue
            }
            if let (level, rest) = heading(trimmed) {
                flushParagraph(); flushList()
                blocks.append(.heading(level, rest))
                continue
            }
            if let (marker, rest) = listItem(trimmed) {
                flushParagraph()
                list.append((marker, rest))
                continue
            }
            flushList()
            paragraph.append(line)
        }
        if let openCode = code { blocks.append(.code(openCode.joined(separator: "\n"), language: language)) }
        flushParagraph(); flushList(); flushTable()
        return blocks
    }

    private static func heading(_ line: String) -> (Int, String)? {
        var level = 0
        var rest = Substring(line)
        while rest.first == "#" { level += 1; rest = rest.dropFirst() }
        guard level > 0, level <= 6, rest.first == " " else { return nil }
        return (level, String(rest.dropFirst()).trimmingWhitespace())
    }

    private static func listItem(_ line: String) -> (String, String)? {
        for bullet in ["- ", "* ", "+ "] where line.hasPrefix(bullet) {
            return ("•", String(line.dropFirst(2)))
        }
        var digits = Substring(line)
        var number = ""
        while let first = digits.first, first.isNumber { number.append(first); digits = digits.dropFirst() }
        if !number.isEmpty, digits.hasPrefix(". ") { return ("\(number).", String(digits.dropFirst(2))) }
        return nil
    }
}

extension String {
    func trimmingWhitespace() -> String {
        var s = Substring(self)
        while let f = s.first, f == " " || f == "\t" { s = s.dropFirst() }
        while let l = s.last, l == " " || l == "\t" || l == "\r" { s = s.dropLast() }
        return String(s)
    }
}
