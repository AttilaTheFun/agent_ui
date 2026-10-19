import SwiftUI

/// Where the caret is in the draft, as UTF-16 offsets, and the words it is
/// in. Kept as offsets, not as the field's own indices: a field's indices
/// are its text's (a Mac's are UTF-16), and read against other words —
/// the draft as it was a moment before, or as the app changed it — they
/// pointed somewhere else (a caret thrown back before the letter just
/// typed) or trapped (past the end of the words, in UTF-16). Offsets are
/// read against nothing but the words they are for.
struct DraftCaret: Equatable {
    var lower: Int
    var upper: Int
    /// The words the offsets are for; nil while the field has said where
    /// its caret went and not yet the words it went in (a Mac's field says
    /// the caret first, then the letter typed), which is settled within
    /// the moment (`ComposerField`).
    var text: String?
    /// What the field is given for these words: its own selection, as it
    /// said it (so the field, comparing, finds nothing to move), or one made
    /// for words the composer set itself.
    var selection: DraftSelection?

    init(lower: Int, upper: Int, text: String?, selection: DraftSelection? = nil) {
        self.lower = lower
        self.upper = max(lower, upper)
        self.text = text
        self.selection = selection
    }

    /// A caret the composer puts in words it sets itself (after a newline,
    /// after a picked command): the field is given a selection made for
    /// them.
    static func placed(_ offset: Int, in text: String) -> DraftCaret {
        let at = Self.index(offset, in: text)
        return DraftCaret(lower: at.utf16Offset(in: text), upper: at.utf16Offset(in: text), text: text,
                          selection: DraftSelection(insertionPoint: at))
    }

    /// The caret the field said, as offsets in `words`, the words it said
    /// it in (none for a selection of many ranges, which the composer does
    /// not make, or for a caret that is not in these words). Read only
    /// once its words are known, and only when it is within them: a
    /// field's index read against words it is not in pointed elsewhere or
    /// trapped.
    @MainActor static func reported(_ selection: DraftSelection, in words: String) -> DraftCaret? {
        guard case .selection(let range) = selection.indices else { return nil }
        guard isWithin(range.lowerBound, words), isWithin(range.upperBound, words) else { return nil }
        return DraftCaret(lower: range.lowerBound.utf16Offset(in: words), upper: range.upperBound.utf16Offset(in: words), text: words,
                          selection: selection)
    }

    /// The caret at the end of `text`.
    static func end(of text: String) -> DraftCaret { placed(text.utf16.count, in: text) }

    /// The offsets, for `text` as it is now: only when they are for these
    /// words (or for the words the field has, not yet said), and within
    /// them.
    func range(in text: String) -> (lower: Int, upper: Int)? {
        guard self.text == nil || self.text == text, upper <= text.utf16.count else { return nil }
        return (lower, upper)
    }

    /// The caret as the field is given it: only for the very words it is
    /// for, and as it was said (the field's own) or made. After the words
    /// changed under it (a correction that lengthened a word, "dont" to
    /// "don't", or the draft cleared), none: a caret for other words, given
    /// back, moved the field's caret (or trapped iOS 18's field).
    func selection(in text: String) -> DraftSelection? {
        guard self.text == text, upper <= text.utf16.count else { return nil }
        return selection
    }

    /// The index at a UTF-16 offset of `text`, moved back to the start of
    /// the character it falls in.
    static func index(_ offset: Int, in text: String) -> String.Index {
        var at = min(max(0, offset), text.utf16.count)
        while at > 0 {
            let candidate = text.utf16.index(text.utf16.startIndex, offsetBy: at)
            if let aligned = String.Index(candidate, within: text) { return aligned }
            at -= 1
        }
        return text.startIndex
    }

    /// An index's offset in its own encoding (UTF-16 for a Mac's or a
    /// phone's field, UTF-8 for a Swift string's): no less than its UTF-16
    /// offset in its own words, whichever it is, so an index whose raw
    /// offset is within words' UTF-16 count is within them. Read against
    /// ASCII, whose UTF-8 and UTF-16 offsets are the same, long enough
    /// (grown as needed: comparing indices reads no words, so cannot trap).
    @MainActor private static var ascii = ""

    /// Whether an index is within words, read without reading them: its raw
    /// offset within their UTF-16 count (so in either encoding), or, for a
    /// Swift string's index (UTF-8, as a field elsewhere than Apple's may
    /// give), within their UTF-8 count.
    @MainActor static func isWithin(_ index: String.Index, _ words: String) -> Bool {
        let raw = rawOffset(of: index)
        if raw <= words.utf16.count { return true }
        return index.debugDescription.hasSuffix("[utf8]") && raw <= words.utf8.count
    }

    @MainActor static func rawOffset(of index: String.Index) -> Int {
        while index > ascii.endIndex { ascii = String(repeating: "a", count: max(4096, ascii.utf16.count * 2)) }
        return index.utf16Offset(in: ascii)
    }
}
