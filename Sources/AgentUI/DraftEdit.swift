/// Edits to a draft that the composer makes itself.
enum DraftEdit {
    /// A newline put where the caret is, in place of whatever is selected:
    /// the new text, and how many characters in the caret now sits. With
    /// no caret known (or one that is not in this text), the newline goes
    /// at the end.
    static func newline(in text: String, replacing range: Range<String.Index>?) -> (text: String, caret: Int) {
        guard let range, range.upperBound <= text.endIndex else {
            return (text + "\n", text.count + 1)
        }
        let before = text.distance(from: text.startIndex, to: range.lowerBound)
        var next = text
        next.replaceSubrange(range, with: "\n")
        return (next, before + 1)
    }
}
