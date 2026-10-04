import SwiftUI

/// Ways to finish the draft, above the field while there are any: worked
/// out from the draft here, so the composer around it does not read the
/// draft and is not redrawn as it is typed.
struct ComposerSuggestions: View {
    @Binding var draft: String
    let suggest: (String) -> [AgentSuggestion]
    let pick: (AgentSuggestion) -> Void

    var body: some View {
        let suggestions = suggest(draft)
        if !suggestions.isEmpty {
            SuggestionList(suggestions: suggestions, pick: pick)
                .padding(.bottom, AgentComposerMetrics.gap)
                .padding(.trailing, AgentComposerMetrics.gap)
        }
    }
}
