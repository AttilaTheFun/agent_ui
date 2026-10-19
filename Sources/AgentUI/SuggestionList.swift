import SwiftUI

/// The suggestions in their menu: a few rows, the rest a scroll away.
struct SuggestionList: View {
    let suggestions: [AgentSuggestion]
    /// The most height the menu has (the room above the composer).
    var room: CGFloat = 230
    let pick: (AgentSuggestion) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(suggestions) { suggestion in
                    Button { pick(suggestion) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.callout.monospaced().weight(.medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            if !suggestion.detail.isEmpty {
                                Text(suggestion.detail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AgentComposerMetrics.inner)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("suggestion-" + suggestion.title)
                }
            }
        }
        // Up to about five rows before it scrolls, fewer where there is
        // less room.
        .frame(height: min(CGFloat(suggestions.count) * 46, 230, room))
        .scrollBounceBehavior(.basedOnSize)
    }
}
