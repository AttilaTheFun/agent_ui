import SwiftUI

extension View {
    /// Key presses, to `handle`, which says whether it took the key: the
    /// keys that are not text, and text with a modifier, go to the
    /// terminal; plain text is left to the field. On every SwiftUI that
    /// reports key presses (Apple's, and Isomer's since 0.18).
    func terminalKeys(_ handle: @escaping (TerminalKey) -> Bool) -> some View {
        onKeyPress(phases: [.down, .repeat]) { press in
            handle(TerminalKey(press)) ? .handled : .ignored
        }
    }
}
