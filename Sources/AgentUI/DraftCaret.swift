import SwiftUI

/// Where the caret is, and the words it is in: the field says where its
/// caret is a moment after the words change, and a caret kept from the
/// words before, handed to the field with the words after, moves the
/// caret back there (a correction that lengthens a word, "dont" to
/// "don't", and what was typed next went in a letter early).
struct DraftCaret {
    let selection: DraftSelection
    /// The words `selection` was given for.
    let text: String

    /// The caret, for `text` as it is now: none while the words are not
    /// the ones it was given for.
    func selection(in text: String) -> DraftSelection? {
        text == self.text && selection.lies(in: text) ? selection : nil
    }

    /// The caret for a newline put in at it (Shift-Return): the one the
    /// field said last, wherever it lies in the words now. Not held to the
    /// words it came with: a Mac's field says where its caret went before
    /// it says the letter typed there, so after any typing the caret came
    /// with the words before, and the newline went at the end.
    func newlineSelection(in text: String) -> DraftSelection? {
        selection.lies(in: text) ? selection : nil
    }
}
