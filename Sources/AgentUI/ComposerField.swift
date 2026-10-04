import SwiftUI

/// The composer's field, and in its place, faint, the words just sent
/// while they are on their way. A view of its own, the one that reads the
/// draft: a keystroke redraws it, not the box around it (the glass, the
/// app's controls).
struct ComposerField: View {
    @Binding var draft: String
    let placeholder: String
    /// The words just sent, while the message is on its way.
    let sentWords: String?
    let sending: Bool
    var focused: FocusState<Bool>.Binding
    /// Bumped after a send: the field is made anew (AgentComposer.fire).
    let generation: Int
    /// Return, or the field's own submit: the composer sends if there is
    /// something to send.
    let submit: () -> Void
    /// Where the caret is, for a Shift-Return's newline.
    @State private var selection: DraftSelection?

    /// The words on their way, while there is nothing new written.
    private var sendingWords: String? { sending && draft.isEmpty ? sentWords : nil }

    var body: some View {
        // Laid out with the field, so the box keeps the words' height
        // until they leave it.
        ZStack(alignment: .topLeading) {
            if let sendingWords {
                Text(sendingWords)
                    .foregroundColor(.secondary)
                    .draftLineLimit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
            }
            DraftField(placeholder: sendingWords == nil ? placeholder : "", draft: $draft, selection: $selection)
                .textFieldStyle(.plain)
                .draftLineLimit()
                .frame(maxWidth: .infinity, alignment: .leading)
                .focused(focused)
                .id(generation)
                .onSubmit(submit)
                // Return sends; Shift-Return is a newline. Where keys can be
                // read (a Mac, a hardware keyboard on a phone), both are
                // decided here and the field sees neither; elsewhere the
                // submit above is what sends.
                .returnSendsShiftReturnBreaks(draft: $draft, selection: $selection, send: submit)
        }
        .draftScroller(draft: draft, selection: selection)
    }
}
