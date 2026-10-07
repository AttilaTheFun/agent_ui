import SwiftUI

/// The composer's text field, with its caret tracked where SwiftUI says
/// where it is (so a newline can go in at the caret).
struct DraftField: View {
    let placeholder: String
    @Binding var draft: String
    @Binding var selection: DraftSelection?

    var body: some View {
        #if os(tvOS)
        // A TV's field is a button for the system keyboard, one line tall:
        // given a vertical axis it grows to whatever height it is offered.
        TextField(placeholder, text: $draft)
        #elseif canImport(AppKit) || canImport(UIKit)
        TextField(placeholder, text: $draft, selection: $selection, axis: .vertical)
        #else
        TextField(placeholder, text: $draft, axis: .vertical)
        #endif
    }
}
