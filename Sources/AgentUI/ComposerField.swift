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
    /// Return, or the field's own submit, with something to send, sends
    /// the words as this view has them (the composer's own reading of the
    /// draft is that of its last redraw, which typing does not cause); a
    /// change of the draft after a hand-over settles it. Held by the
    /// composer across its passes.
    let actions: ComposerActions
    /// Counts suggestions picked: each puts the caret after the words, past
    /// the command it finished (not where the caret was in what was typed).
    var picked = 0
    /// Where the caret is (DraftCaret: offsets, and the words they are
    /// for), for a Shift-Return's newline and the field's own caret.
    @State private var caret: DraftCaret?
    /// The caret the field said, until the words it is in are known (a
    /// Mac's field says its caret first, then the letter typed).
    @State private var said: DraftSelection?

    /// The words on their way, while there is nothing new written.
    private var sendingWords: String? { sending && draft.isEmpty ? sentWords : nil }

    /// The caret after the last of the words: once the picked words are in
    /// the field (the next turn of the main actor), so the field does not
    /// put it back where it was in the words before.
    private func caretToEnd() {
        Task { @MainActor in caret = DraftCaret.end(of: draft) }
    }

    /// The draft as the field has it: words the field sets are the ones a
    /// caret it just said is in.
    private var fieldText: Binding<String> {
        Binding(get: { draft }, set: { words in
            draft = words
            settle(in: words)
        })
    }

    /// The caret as the field says it; given back only for the very words
    /// it is for (DraftCaret.selection(in:)). A caret said with no words
    /// after it (a click, an arrow key) is in the words there are, which
    /// the end of the moment settles.
    private var fieldSelection: Binding<DraftSelection?> {
        // In the moment between its caret and its words, the field is given
        // back what it just said: anything else, it moves its caret to.
        Binding(get: { said ?? caret?.selection(in: draft) }, set: { new in
            said = new
            if new == nil { caret = nil }
            Task { @MainActor in settle(in: draft) }
        })
    }

    /// The caret the field said, read in the words it is in.
    private func settle(in words: String) {
        guard let pending = said else { return }
        said = nil
        caret = DraftCaret.reported(pending, in: words)
    }

    /// The caret now, for a Shift-Return: the one the field said last, read
    /// in the draft if it had not been yet.
    private var newlineCaret: Binding<DraftCaret?> {
        Binding(get: {
            if let pending = said { return DraftCaret.reported(pending, in: draft) }
            return caret
        }, set: { new in
            said = nil
            caret = new
        })
    }

    private func submitIfAny() {
        if !AgentText.isBlank(draft) || attachmentCount > 0 { actions.send(draft) }
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
            DraftField(placeholder: sendingWords == nil ? placeholder : "", draft: fieldText, selection: fieldSelection)
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
                .returnSendsShiftReturnBreaks(draft: $draft, caret: newlineCaret, send: submitIfAny)
        }
        .draftScroller(draft: draft, caret: caret)
        .onChange(of: draft) { _, now in if handedOver { actions.settle(now.isEmpty) } }
        .onChange(of: picked) { _, _ in caretToEnd() }
    }
}
