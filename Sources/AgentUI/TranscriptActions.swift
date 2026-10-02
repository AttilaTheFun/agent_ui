import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The two things a host has to lend the transcript: somewhere to put
/// text, and somewhere to send it. Apple has both of its own.
///
/// Main-actor state: set as the app starts, read from views.
@MainActor
public enum TranscriptActions {
    public static var copy: ((String) -> Void)?
    public static var share: ((String) -> Void)?

    static func put(_ text: String) {
        if let copy { copy(text); return }
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        // UIKit's pasteboard, which the portable SwiftUI has too (the
        // browser's clipboard, Android's).
        UIPasteboard.general.string = text
        #endif
    }
}
