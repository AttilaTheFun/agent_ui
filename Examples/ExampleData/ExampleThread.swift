import MessagesUI
import SwiftUI

/// The thread for a conversation in the store: the same page in every
/// example, with an example custom renderer for the "build" kind.
public struct ExampleThread: View {
    @ObservedObject var store: ExampleStore
    let id: String
    let onTitleTap: () -> Void
    @State private var draft = ""

    public init(store: ExampleStore, id: String, onTitleTap: @escaping () -> Void) {
        self.store = store
        self.id = id
        self.onTitleTap = onTitleTap
    }

    public var body: some View {
        if let conversation = store.conversation(id) {
            ThreadView(
                conversation: conversation,
                messages: store.messages(in: id),
                emptyText: "Say something.",
                draft: $draft,
                send: { store.send(draft, to: id); draft = "" },
                onTitleTap: onTitleTap
            )
            .messageContentRenderer { kind, payload, _ in
                guard kind == "build" else { return nil }
                return AnyView(
                    Label("Build \(payload)", systemImage: payload == "passed" ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.22)).cornerRadius(18)
                )
            }
        }
    }
}
