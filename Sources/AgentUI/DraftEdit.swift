/// Edits to a draft that the composer makes itself.
enum DraftEdit {
    /// A newline put where the caret is (UTF-16 offsets), in place of
    /// whatever is selected: the new text, and the caret's offset after it.
    /// With no caret known, the newline goes at the end.
    static func newline(in text: String, replacing range: (lower: Int, upper: Int)?) -> (text: String, caret: Int) {
        guard let range else { return (text + "\n", text.utf16.count + 1) }
        let start = DraftCaret.index(range.lower, in: text), end = DraftCaret.index(range.upper, in: text)
        var next = text
        next.replaceSubrange(start..<max(start, end), with: "\n")
        return (next, start.utf16Offset(in: text) + 1)
    }
}
