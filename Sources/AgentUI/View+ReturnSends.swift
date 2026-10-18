import SwiftUI

extension View {
    /// Return sends and Shift-Return inserts a newline where the caret is,
    /// on the platforms whose SwiftUI reports key presses.
    @ViewBuilder func returnSendsShiftReturnBreaks(draft: Binding<String>, caret: Binding<DraftCaret?>,
                                                   send: @escaping () -> Void) -> some View {
        #if canImport(AppKit) || canImport(UIKit)
        self.onKeyPress(.return, phases: .down) { press in
            if press.modifiers.contains(.shift) {
                let words = draft.wrappedValue
                let edit = DraftEdit.newline(in: words, replacing: caret.wrappedValue?.range(in: words))
                draft.wrappedValue = edit.text
                // The caret follows the newline, rather than jumping to the
                // end as it does when the text changes under the field.
                caret.wrappedValue = DraftCaret.placed(edit.caret, in: edit.text)
            } else {
                send()
            }
            return .handled
        }
        #else
        self
        #endif
    }
}
