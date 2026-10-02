/// What the transcript draws in one slot: a message, or a run of tool
/// calls folded into one row. A run is consecutive messages that are only
/// tool calls and their results — an assistant row with activities and no
/// words, a tool row with no picture — and is folded into one row however
/// many calls it holds, so the row keeps one identity as the run grows.
public enum TranscriptBlock: Identifiable {
    case message(TranscriptMessage)
    case calls([TranscriptMessage])

    public var id: String {
        switch self {
        case .message(let message): message.id
        case .calls(let run): "calls-" + (run.first?.id ?? "")
        }
    }

    /// Whether a message is a tool call or a tool result and nothing else.
    static func isCall(_ message: TranscriptMessage) -> Bool {
        switch message.role {
        case .assistant: message.text.isEmpty && !message.activities.isEmpty
        case .tool: message.imageURLs.isEmpty && !GoalRow.shows(message)
        case .user: false
        }
    }

    /// The number of calls in a run: one per activity label.
    public static func callCount(_ run: [TranscriptMessage]) -> Int {
        run.reduce(0) { $0 + $1.activities.count }
    }

    public static func blocks(_ messages: [TranscriptMessage]) -> [TranscriptBlock] {
        var out: [TranscriptBlock] = []
        var run: [TranscriptMessage] = []
        func flush() {
            guard !run.isEmpty else { return }
            // A run is one row from its first call, under that call's id,
            // however many follow: the row counts up in place rather than
            // a lone call's row giving way to a group's.
            out.append(.calls(run))
            run = []
        }
        for message in messages {
            if isCall(message) {
                run.append(message)
            } else if message.role == .assistant, !message.text.isEmpty, !message.activities.isEmpty {
                // Words and then calls in one message: the words are a row
                // of their own and the calls start (or join) a run, so a
                // turn that speaks and then works reads as one run of work.
                flush()
                var words = message
                words.activities = []
                out.append(.message(words))
                var calls = message
                calls.id = message.id + "#calls"
                calls.text = ""
                run.append(calls)
            } else {
                flush()
                out.append(.message(message))
            }
        }
        flush()
        return out
    }
}
