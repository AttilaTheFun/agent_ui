import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// What a host may lend the transcript: somewhere to put text. Apple's
/// pasteboard, and the portable SwiftUI's, are used otherwise. (Sharing is
/// ShareLink everywhere.)
///
/// Main-actor state: set as the app starts, read from views.
@MainActor
public enum TranscriptActions {
    public static var copy: ((String) -> Void)?

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
