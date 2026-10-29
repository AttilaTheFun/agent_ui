import SwiftUI

/// What to do with something the agent said: take all of it, send it
/// on, or go on from it in a branch of the conversation. Selecting part of
/// it is the text's own business — these are for when the whole thing is
/// wanted. No taking or sending where the host keeps the transcript in the
/// app (`transcriptSharingAllowed`); a branch where the app takes one
/// (`AgentView`'s `branchFromHere`) and the message has an id.
public struct MessageActions: View {
    let text: String
    let id: String?
    @State private var copied = false
    @Environment(\.transcriptSharingAllowed) private var sharingAllowed
    @Environment(\.branchFromMessage) private var branch

    public init(text: String, id: String? = nil) {
        self.text = text
        self.id = id
    }

    public var body: some View {
        if sharingAllowed || (branch != nil && id != nil) { actions }
    }

    private var actions: some View {
        HStack(spacing: 14) {
            if sharingAllowed {
                Button {
                    TranscriptActions.put(text)
                    copied = true
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copied ? "Copied" : "Copy")
                .accessibilityIdentifier("copy-message")
                share
            }
            if let branch, let id {
                Button {
                    branch(id)
                } label: {
                    Image(systemName: "arrow.triangle.branch")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Branch from Here")
                .accessibilityIdentifier("branch-message")
            }
            Spacer()
        }
        .font(.body.weight(.semibold))
        .foregroundColor(.secondary)
        .padding(.top, 4)
    }

    /// The system's share sheet (the web's navigator.share or clipboard,
    /// Android's chooser, as Isomer carries ShareLink there).
    private var share: some View {
        ShareLink(item: text) {
            Image(systemName: "square.and.arrow.up")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("share-message")
    }
}
