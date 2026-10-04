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
    /// Bumped after a send: the field is made anew (AgentComposer.settle).
    let generation: Int
    let attachmentCount: Int
    /// Words were handed to the app, and the draft has not changed since.
    let handedOver: Bool
    /// Return, or the field's own submit, with something to send: the
    /// words as this view has them. (The composer's own reading of the
    /// draft is that of its last redraw, which typing does not cause.)
    let submit: (String) -> Void
    /// The draft changed after a hand-over: cleared, or kept.
    let settle: (_ cleared: Bool) -> Void
    /// Where the caret is, for a Shift-Return's newline.
    @State private var selection: DraftSelection?

    /// The words on their way, while there is nothing new written.
    private var sendingWords: String? { sending && draft.isEmpty ? sentWords : nil }

    private func submitIfAny() {
        if !AgentText.isBlank(draft) || attachmentCount > 0 { submit(draft) }
    }

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
                .onSubmit(submitIfAny)
                // Return sends; Shift-Return is a newline. Where keys can be
                // read (a Mac, a hardware keyboard on a phone), both are
                // decided here and the field sees neither; elsewhere the
                // submit above is what sends.
                .returnSendsShiftReturnBreaks(draft: $draft, selection: $selection, send: submitIfAny)
        }
        .draftScroller(draft: draft, selection: selection)
        .onChange(of: draft) { _, now in if handedOver { settle(now.isEmpty) } }
    }
}
