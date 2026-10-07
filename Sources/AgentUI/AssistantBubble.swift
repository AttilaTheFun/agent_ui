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
                .selectableText()
                .frame(maxWidth: .infinity, alignment: .leading)
            // (Not on a TV: no pasteboard to copy to, no sheet to share with.)
            if !text.isEmpty, !AgentComposerMetrics.tv { MessageActions(text: text) }
        }
        .padding(.horizontal, TranscriptMetrics.edgeInset)
    }
}
