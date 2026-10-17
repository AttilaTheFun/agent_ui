import SwiftUI

/// The composer's text field, with its caret tracked (so a newline can go
/// in at the caret, and a picked command leaves the caret after it).
struct DraftField: View {
    let placeholder: String
    @Binding var draft: String
    @Binding var selection: DraftSelection?

    var body: some View {
        TextField(placeholder, text: $draft, selection: $selection, axis: .vertical)
    }
}
