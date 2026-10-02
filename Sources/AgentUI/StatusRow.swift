import SwiftUI

/// The transcript's last row, always there and always one line tall: a
/// spinner and what the agent is doing while it works — the latest tool
/// running, else the task under way, else the label ("Thinking…") — and
/// the last failure while it is idle. Hidden, not removed, when there is
/// nothing to say, so the thread never changes height for it.
struct StatusRow: View {
    let busy: Bool
    let status: [ActivityItem]
    let activity: String?
    let error: String?
    /// Bumped each time the row comes on screen: a list keeps the row
    /// while it is off screen, and a spinner kept that way comes back
    /// still. A new one spins.
    @State private var shown = 0

    var body: some View {
        VStack(spacing: 0) {
            // The spinner and the words are always there, hidden when
            // there is nothing to say; they change without animation, so
            // the row never grows, shrinks or fades as the thread moves.
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).id(shown)
                    .opacity(line == nil ? 0 : 1)
                if let symbol = line?.symbol, !symbol.isEmpty {
                    Image(systemName: symbol).foregroundColor(.secondary).font(.footnote)
                }
                Text(line?.label ?? error ?? "")
                    .font(.footnote)
                    .foregroundColor(line == nil && error != nil ? .red : .secondary)
                Spacer(minLength: 0)
            }
            .lineLimit(1)
            .frame(height: 20)
            .padding(.horizontal, TranscriptMetrics.edgeInset)
            .transaction { $0.animation = nil }
            Color.clear.frame(height: TranscriptMetrics.bottomGap)
        }
        .onAppear { shown &+= 1 }
    }

    private var line: (label: String, symbol: String?)? {
        if let item = status.last(where: { $0.running && $0.kind != .tasks }) {
            return (item.label, Self.symbol(for: item.kind))
        }
        guard busy || activity != nil else { return nil }
        if let tasks = status.last(where: { $0.kind == .tasks })?.tasks,
           let index = tasks.firstIndex(where: { $0.state == .active }) {
            return ("\(tasks[index].title) (\(index + 1) of \(tasks.count))", Self.symbol(for: .tasks))
        }
        return (activity ?? "Thinking…", nil)
    }

    static func symbol(for kind: ActivityItem.Kind) -> String {
        switch kind {
        case .thinking: ""
        case .shell: "terminal"
        case .monitor: "eye"
        case .subagent: "person.2"
        case .tool: "wrench.and.screwdriver"
        case .tasks: "checklist"
        }
    }
}
