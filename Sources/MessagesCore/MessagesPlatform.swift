import SwiftUI

/// Where this is running, for the few places Messages.app itself differs:
/// the composer's send button, the title's size, which bar owns compose.
/// Compile-time, so the same source resolves on every SwiftUI.
public enum MessagesPlatform {
    public static var isMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    /// A desktop: Return sends, no send button.
    public static var isDesktop: Bool {
        #if os(macOS) || os(Linux) || os(Windows)
        true
        #else
        false
        #endif
    }

    /// The web: a phone when narrow, a desktop when wide.
    public static var isWeb: Bool {
        #if os(WASI)
        true
        #else
        false
        #endif
    }
}
