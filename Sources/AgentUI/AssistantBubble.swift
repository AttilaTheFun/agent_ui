import SwiftUI

public struct AssistantBubble: View {
    let text: String

    public init(text: String) {
        self.text = text
    }

    /// No avatar or glyph beside the text: on a phone the width is the
    /// message's. Ours are the gray bubbles on the right; the agent's is
    /// plain text from the left edge.
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MarkdownText(text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !text.isEmpty { MessageActions(text: text) }
        }
        .padding(.horizontal, TranscriptMetrics.edgeInset)
    }
}
