enum MarkdownBlock {
    case paragraph(String)
    case heading(Int, String)
    case code(String, language: String)
    case list([(marker: String, text: String)])
    case table(header: [String], rows: [[String]])
    /// Lines that began with ">", without it: markdown of their own (a
    /// list, code, a quote in the quote).
    case quote(String)
}
