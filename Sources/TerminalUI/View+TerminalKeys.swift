import SwiftUI

extension View {
    /// Key presses, to `handle`, which says whether it took the key, where
    /// the platform's SwiftUI reports them; elsewhere typing reaches the
    /// terminal through the field and the key bar alone.
    @ViewBuilder func terminalKeys(_ handle: @escaping (TerminalKey) -> Bool) -> some View {
        #if canImport(UIKit) || canImport(AppKit)
        onKeyPress(phases: [.down, .repeat]) { press in
            handle(TerminalKey(press)) ? .handled : .ignored
        }
        #else
        self
        #endif
    }
}
