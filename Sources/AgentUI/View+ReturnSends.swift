import SwiftUI

extension View {
    /// Return sends and Shift-Return inserts a newline where the caret is,
    /// on the platforms whose SwiftUI reports key presses.
    @ViewBuilder func returnSendsShiftReturnBreaks(draft: Binding<String>, selection: Binding<DraftSelection?>,
                                                   send: @escaping () -> Void) -> some View {
        #if canImport(AppKit) || canImport(UIKit)
        self.onKeyPress(.return, phases: .down) { press in
            if press.modifiers.contains(.shift) {
                var range: Range<String.Index>?
                if case .selection(let selected) = selection.wrappedValue?.indices { range = selected }
                let edit = DraftEdit.newline(in: draft.wrappedValue, replacing: range)
                draft.wrappedValue = edit.text
                // The caret follows the newline, rather than jumping to the
                // end as it does when the text changes under the field.
                selection.wrappedValue = TextSelection(insertionPoint: edit.text.index(edit.text.startIndex, offsetBy: edit.caret))
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
