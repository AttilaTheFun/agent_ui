import SwiftUI
#if canImport(Isomer)
import Isomer
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// What a host may lend the transcript: somewhere to put text. Otherwise
/// the system's: Apple's pasteboard, or Isomer's clipboard (the browser's,
/// Android's) where Isomer builds the views. (Sharing is ShareLink
/// everywhere.)
///
/// Main-actor state: set as the app starts, read from views.
@MainActor
public enum TranscriptActions {
    public static var copy: ((String) -> Void)?

    static func put(_ text: String) {
        if let copy { copy(text); return }
        #if canImport(Isomer)
        Clipboard.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
