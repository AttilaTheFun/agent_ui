import SwiftUI

extension View {
    /// Return sends and Shift-Return inserts a newline, on the platforms
    /// whose SwiftUI reports key presses.
    @ViewBuilder func returnSendsShiftReturnBreaks(draft: Binding<String>, send: @escaping () -> Void) -> some View {
        #if canImport(AppKit) || canImport(UIKit)
        self.onKeyPress(.return, phases: .down) { press in
            if press.modifiers.contains(.shift) {
                draft.wrappedValue += "\n"
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
