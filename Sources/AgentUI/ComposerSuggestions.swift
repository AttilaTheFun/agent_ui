import SwiftUI

/// Ways to finish the draft, a menu above the composer while there are
/// any: worked out from the draft here, so the composer around it does not
/// read the draft and is not redrawn as it is typed. On a phone or an iPad,
/// a popover, drawn over everything as a context menu is (a phone held
/// sideways has room above its composer only under the navigation bar,
/// which takes the taps there); the field keeps the keyboard, so typing on
/// narrows it, and a tap outside it puts it away until the draft changes.
/// Elsewhere, a menu floating above the box, as tall as its rows or the
/// room above the composer (`room`, from the window's top).
struct ComposerSuggestions: View {
    @Binding var draft: String
    let suggest: (String) -> [AgentSuggestion]
    let room: CGFloat
    let pick: (AgentSuggestion) -> Void
    /// The draft the popover was put away for.
    @State private var dismissed: String?

    var body: some View {
        let suggestions = suggest(draft)
        #if os(iOS)
        Color.clear
            .frame(width: 44, height: 1)
            .popover(isPresented: Binding(get: { !suggestions.isEmpty && dismissed != draft },
                                          set: { if !$0 { dismissed = draft } }),
                     attachmentAnchor: .point(.top), arrowEdge: .bottom) {
                // Clear of the popover's rounded corners.
                SuggestionList(suggestions: suggestions, pick: pick)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 6)
                    .frame(width: 332)
                    .presentationCompactAdaptation(.popover)
            }
        #else
        if !suggestions.isEmpty {
            SuggestionList(suggestions: suggestions, room: max(46, room - 12), pick: pick)
                .padding(.vertical, 4)
                .frame(maxWidth: 360, alignment: .leading)
                .modifier(SuggestionMenuBackground())
        }
        #endif
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
