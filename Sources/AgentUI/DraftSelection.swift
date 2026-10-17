import SwiftUI

/// Where the caret is in the composer's field, as SwiftUI says (Apple's,
/// and Isomer's on every host).
typealias DraftSelection = TextSelection

extension DraftSelection {
    /// Whether it lies in `text`. One kept from other words (the draft
    /// cleared, or a picked command in its place) may not, and a field
    /// handed it traps on iOS 18 (iOS 26's clamps it).
    func lies(in text: String) -> Bool {
        guard case .selection(let range) = indices else { return true }
        return String.Index(range.lowerBound, within: text) != nil && String.Index(range.upperBound, within: text) != nil
    }
}
