/// A message's blocks as they are drawn: each run of paragraphs and
/// headings as one text, so a selection goes from one into the next, and
/// every other block (a list, code, a table, a quote) a view of its own.
enum MarkdownRun {
    case prose([MarkdownBlock])
    case block(MarkdownBlock)

    static func runs(_ blocks: [MarkdownBlock]) -> [MarkdownRun] {
        var runs: [MarkdownRun] = []
        for block in blocks {
            switch block {
            case .paragraph, .heading:
                if case .prose(let earlier)? = runs.last {
                    runs[runs.count - 1] = .prose(earlier + [block])
                } else {
                    runs.append(.prose([block]))
                }
            default:
                runs.append(.block(block))
            }
        }
        return runs
    }
}
