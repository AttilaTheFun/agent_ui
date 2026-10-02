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
