import SwiftUI

/// Ways to finish the draft, a menu above the composer while there are
/// any: worked out from the draft here, so the composer around it does not
/// read the draft and is not redrawn as it is typed. As tall as its rows,
/// or the room above the composer (`room`, from the window's top), and
/// scrolled beyond that.
struct ComposerSuggestions: View {
    @Binding var draft: String
    let suggest: (String) -> [AgentSuggestion]
    let room: CGFloat
    let pick: (AgentSuggestion) -> Void

    var body: some View {
        let suggestions = suggest(draft)
        if !suggestions.isEmpty {
            SuggestionList(suggestions: suggestions, room: max(46, room - 12), pick: pick)
                .padding(.vertical, 4)
                .frame(maxWidth: 360, alignment: .leading)
                .modifier(SuggestionMenuBackground())
        }
    }
}

/// The menu's look: the composer's material, raised a little off what it
/// covers.
private struct SuggestionMenuBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 18))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        }
    }
}
