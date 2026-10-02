import MessagesCore
import SwiftUI

/// The composer's geometry, shared with the thread. On a phone the bubbles
/// sit 16pt from the edges, always; the composer sits with them while the
/// keyboard is up and moves out to 24pt when it is away, to sit with the
/// screen's corners. On a desktop both are 12pt.
public enum ComposerMetrics {
    public static func isPhoneComposer(sizeClass: UserInterfaceSizeClass?) -> Bool {
        if MessagesPlatform.isDesktop { return false }
        if MessagesPlatform.isWeb { return sizeClass == .compact }
        return true
    }

    /// The composer's side inset.
    public static func horizontalInset(sizeClass: UserInterfaceSizeClass?, keyboardVisible: Bool) -> CGFloat {
        // The 24pt rests inside an iPhone's rounded corners; a browser tab
        // has no such corners, so the web keeps the messages' 16pt throughout.
        isPhoneComposer(sizeClass: sizeClass) ? ((keyboardVisible || MessagesPlatform.isWeb) ? 16 : 24) : 12
    }

    /// The messages' side inset: the composer's with the keyboard up.
    public static func messageInset(sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        isPhoneComposer(sizeClass: sizeClass) ? 16 : 12
    }
}
