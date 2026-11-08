import SwiftUI

/// Mail between sessions in the thread (a tool row named "mail"): a
/// message another session sent, or word that some wait unread, shown
/// apart from the person's own words. Long words fold to a few lines, and
/// a tap unfolds them.
struct MailRow: View {
    let text: String
    @State private var expanded = false

    /// Whether a message is mail, shown as its own row.
    nonisolated static func shows(_ message: TranscriptMessage) -> Bool {
        message.role == .tool && message.toolName == "mail"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "envelope.fill")
                .font(.footnote)
                .foregroundColor(.accentColor)
            Text(text)
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(expanded ? nil : 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transcriptTextSelection()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.08)))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.smooth(duration: 0.25)) { expanded.toggle() } }
        .padding(.horizontal, TranscriptMetrics.edgeInset)
        .accessibilityElement(children: .combine)
    }
}
