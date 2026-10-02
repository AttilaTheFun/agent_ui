enum MarkdownBlock {
    case paragraph(String)
    case heading(Int, String)
    case code(String, language: String)
    case list([(marker: String, text: String)])
    case table(header: [String], rows: [[String]])
}
