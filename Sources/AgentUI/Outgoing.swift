import SwiftUI

// What has been said from the composer and is not on the record yet. It is
// shown in the composer, over the field, not in the thread: the thread
// holds only what the agent has, so nothing in it moves or changes places
// when a message lands. A message handed over is sending and stays so; one
// waiting for the turn in flight is queued, and can be taken back to edit.

/// A message said from the composer and not on the record yet.
public struct OutgoingMessage: Identifiable, Equatable, Sendable {
    public enum State: Equatable, Sendable {
        /// Handed over; it can no longer be taken back.
        case sending
        /// Waiting for the turn in flight to end; it can be taken back.
        case queued
    }
    public var id: String
    public var text: String
    /// How many pictures go with it.
    public var imageCount: Int
    public var state: State
    /// Whether a queued message can be taken back to edit: the app may
    /// not be able to give back what went with it.
    public var editable: Bool

    public init(id: String, text: String, imageCount: Int = 0, state: State, editable: Bool = true) {
        self.id = id; self.text = text; self.imageCount = imageCount; self.state = state; self.editable = editable
    }

    var canTakeBack: Bool { state == .queued && editable }
}

/// The composer's outgoing messages, oldest first, one line each.
struct OutgoingList: View {
    let messages: [OutgoingMessage]
    /// Takes a queued message back into the field.
    let edit: ((OutgoingMessage) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(messages) { message in
                if message.canTakeBack, let edit {
                    Button { edit(message) } label: { row(message) }
                        .buttonStyle(.plain)
                        .accessibilityHint("Takes it back to edit")
                } else {
                    row(message)
                }
            }
        }
    }

    private func row(_ message: OutgoingMessage) -> some View {
        HStack(spacing: AgentComposerMetrics.gap) {
            Text(summary(message))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            switch message.state {
            case .sending:
                ProgressView().controlSize(.small)
                Text("Sending").font(.caption).foregroundColor(.secondary)
            case .queued:
                if message.canTakeBack, edit != nil { Image(systemName: "pencil").font(.caption).foregroundColor(.secondary) }
                Text("Queued").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, AgentComposerMetrics.inner)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func summary(_ message: OutgoingMessage) -> String {
        let text = message.text.split(whereSeparator: \.isNewline).joined(separator: " ")
        guard message.imageCount > 0 else { return text }
        let pictures = message.imageCount == 1 ? "1 picture" : "\(message.imageCount) pictures"
        return text.isEmpty ? pictures : text + " · " + pictures
    }
}
