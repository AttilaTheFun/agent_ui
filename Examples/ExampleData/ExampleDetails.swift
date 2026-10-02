import MessagesUI
import SwiftUI

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
