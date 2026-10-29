// MarkdownViews, to every importer of AgentUI as before it was its own
// module.
@_exported import MarkdownViews
import SwiftUI

public struct AssistantBubble: View {
    let text: String
    /// The message's, for the actions under it that go by it (a branch).
    let id: String?

    public init(text: String, id: String? = nil) {
        self.text = text
        self.id = id
    }

    /// No avatar or glyph beside the text: on a phone the width is the
    /// message's. Ours are the gray bubbles on the right; the agent's is
    /// plain text from the left edge.
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MarkdownText(text)
                .transcriptTextSelection()
                .frame(maxWidth: .infinity, alignment: .leading)
            if !text.isEmpty { MessageActions(text: text, id: id) }
        }
        .padding(.horizontal, TranscriptMetrics.edgeInset)
    }
}
