import Foundation
import InboxUI
import MessagesUI
import SwiftUI

/// A stand-in for a real data source: a few conversations with histories,
/// and an echo that replies to anything sent. The examples all share it.
@MainActor
public final class ExampleStore: ObservableObject {
    @Published public private(set) var conversations: [ConversationSummary]
    @Published private var histories: [String: [MessageItem]]

    public init() {
        let now = Date()
        let people = [
            ("ada", "Ada", Presence.online, "See you at the lab at 9."),
            ("grace", "Grace", Presence.idle, "The compiler build passed."),
            ("linus", "Linus", Presence.offline, "Rebased onto main."),
            ("margaret", "Margaret", Presence.online, "Landing sequence reviewed."),
        ]
        var summaries: [ConversationSummary] = []
        var histories: [String: [MessageItem]] = [:]
        for (index, person) in people.enumerated() {
            let when = now.addingTimeInterval(-Double(index) * 3600 * 9)
            summaries.append(ConversationSummary(id: person.0, name: person.1, presence: person.2,
                                                 preview: person.3, timestamp: when))
            var history: [MessageItem] = []
            for n in 0..<14 {
                let mine = n % 2 == 0
                let line = mine
                    ? ["Hi \(person.1), how is it going?", "Did the build finish?", "I can review it tonight.",
                       "Sending the notes now.", "Same time tomorrow?", "Thanks!", "Got it."][n / 2 % 7]
                    : ["Going well.", "Almost — one test left.", "Perfect, I'll push the branch.",
                       "Received, reading.", "Works for me.", "Any time.", person.3][n / 2 % 7]
                history.append(MessageItem(id: "\(person.0)-\(n)", isMine: mine, text: line,
                                           timestamp: when.addingTimeInterval(Double(n - 14) * 600)))
            }
            histories[person.0] = history
        }
        histories["grace"]?.append(MessageItem(
            id: "grace-3", isMine: false,
            content: .custom(kind: "build", payload: "passed"), timestamp: now.addingTimeInterval(-3600 * 8)
        ))
        self.conversations = summaries
        self.histories = histories
    }

    public func messages(in id: String) -> [MessageItem] { histories[id] ?? [] }

    public func conversation(_ id: String) -> ConversationSummary? { conversations.first { $0.id == id } }

    public func send(_ text: String, to id: String) {
        let now = Date()
        histories[id, default: []].append(MessageItem(id: UUID().uuidString, isMine: true, text: text, timestamp: now))
        update(id, preview: text, at: now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            let reply = "You said: \(text)"
            self?.histories[id, default: []].append(MessageItem(id: UUID().uuidString, isMine: false, text: reply, timestamp: Date()))
            self?.update(id, preview: reply, at: Date())
        }
    }

    private func update(_ id: String, preview: String, at date: Date) {
        guard let at = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[at].preview = preview
        conversations[at].timestamp = date
    }
}

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

/// What the examples put in the details pane.
public struct ExampleDetails: View {
    let conversation: ConversationSummary

    public init(conversation: ConversationSummary) {
        self.conversation = conversation
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Avatar(conversation.avatar, size: 72, presence: conversation.presence)
                Text(conversation.name).font(.title2.weight(.semibold))
                Text("Anything the app wants here: keys, media, mute, block.")
                    .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            .padding(16)
        }
        .frame(minWidth: 260)
    }
}
