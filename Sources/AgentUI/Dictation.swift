import SwiftUI

/// Speech into the draft, as the app provides it: started by the
/// composer's microphone button (shown in the send button's place while
/// there is nothing written), the words so far handed back as they come,
/// stopped by the same button, after which what was heard is sent as
/// any message. The app's object does the listening (the system's speech
/// recognition, on a phone or a Mac); the composer draws the buttons.
@MainActor
public protocol Dictation: AnyObject {
    /// Starts listening. `heard` is called with everything heard so far,
    /// each time more comes. Throws when the system refuses (no
    /// permission, no microphone).
    func start(heard: @escaping @MainActor @Sendable (String) -> Void) async throws
    /// Stops listening; what was heard stays in the draft.
    func stop()
}
