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
}
