import SwiftUI

extension View {
    /// Its words selectable, as the transcript's are, unless the host
    /// keeps the transcript in the app (`transcriptSharingAllowed`).
    func transcriptTextSelection() -> some View { modifier(TranscriptTextSelection()) }
}

private struct TranscriptTextSelection: ViewModifier {
    @Environment(\.transcriptSharingAllowed) private var allowed

    @ViewBuilder func body(content: Content) -> some View {
        if allowed {
            content.textSelection(.enabled)
        } else {
            content
        }
    }
}
