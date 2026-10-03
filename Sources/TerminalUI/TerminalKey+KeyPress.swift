import SwiftUI

#if canImport(UIKit) || canImport(AppKit)
extension TerminalKey {
    /// A key press as SwiftUI reports it.
    init(_ press: KeyPress) {
        var modifiers: TerminalModifiers = []
        if press.modifiers.contains(.shift) { modifiers.insert(.shift) }
        if press.modifiers.contains(.option) { modifiers.insert(.option) }
        if press.modifiers.contains(.control) { modifiers.insert(.control) }
        if press.modifiers.contains(.command) { modifiers.insert(.command) }
        let name = Self.name(of: press.key)
        self.init(name: name, character: name == nil ? press.key.character : nil, modifiers: modifiers)
    }

    /// The browser name of a key that is not text.
    static func name(of key: KeyEquivalent) -> String? {
        switch key {
        case .return: "Enter"
        case .delete: "Backspace"
        case .deleteForward: "Delete"
        case .escape: "Escape"
        case .tab: "Tab"
        case .upArrow: "ArrowUp"
        case .downArrow: "ArrowDown"
        case .leftArrow: "ArrowLeft"
        case .rightArrow: "ArrowRight"
        case .home: "Home"
        case .end: "End"
        case .pageUp: "PageUp"
        case .pageDown: "PageDown"
        default: nil
        }
    }
}
#endif
