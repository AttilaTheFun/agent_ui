import SwiftUI

/// A goal the user set (`/goal`): the agent keeps working until it is met.
/// Set, it says what it asks; met, why it is. Long words fold to a few
/// lines, and a tap unfolds them.
struct GoalRow: View {
    let text: String
    let met: Bool
    @State private var expanded = false

    /// Whether a message is a goal's, shown as its own row.
    nonisolated static func shows(_ message: TranscriptMessage) -> Bool {
        message.role == .tool && (message.toolName == "goal" || message.toolName == "goal-met")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(met ? "Goal met" : "Goal set", systemImage: met ? "checkmark.seal.fill" : "flag.fill")
                .font(.footnote.weight(.semibold))
                .foregroundColor(met ? .green : .accentColor)
            if !text.isEmpty {
                Text(text)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(expanded ? nil : 3)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill((met ? Color.green : Color.accentColor).opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke((met ? Color.green : Color.accentColor).opacity(0.3), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.smooth(duration: 0.25)) { expanded.toggle() } }
        .padding(.horizontal, TranscriptMetrics.edgeInset)
        .accessibilityElement(children: .combine)
    }
}
