import SwiftUI

/// Inline markdown → concatenated styled `Text`: **bold**, *italic* or
/// _italic_, `code`, [title](url), ~~strike~~. Unbalanced markers stay as text.
enum InlineMarkdown {
    struct Span { var text: String; var bold = false; var italic = false; var code = false; var link = false; var strike = false }

    static func text(_ markdown: String) -> Text {
        let spans = parse(markdown)
        var result: Text? = nil
        for span in spans {
            var piece = Text(span.text)
            // Semibold, as Apple's markdown draws **strong** (lighter than
            // .bold(): the same line is 339pt there, 348pt bold).
            if span.bold { piece = piece.fontWeight(.semibold) }
            if span.italic { piece = piece.italic() }
            if span.code { piece = piece.monospaced() }
            if span.strike { piece = piece.strikethrough() }
            // Semibold, as MarkdownText's attributed links are.
            if span.link { piece = piece.underline().fontWeight(.semibold).foregroundColor(.secondary) }
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
