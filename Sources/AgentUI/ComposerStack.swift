import SwiftUI

// Over the composer's field: everything about the turn that changes often
// and is not the record — the model thinking, subagents and tool calls
// while they run, the task list, the last failure, what is being sent and
// what waits. The thread above holds the record and the replies being
// written; it does not move for any of this.

/// The stack over the composer's field, top to bottom: a failure, what is
/// running, the task list, then the messages said and not on the record.
struct ComposerStack: View {
    let status: [ActivityItem]
    let activity: String?
    let error: String?
    let outgoing: [OutgoingMessage]
    let edit: ((OutgoingMessage) -> Void)?

    static func isEmpty(status: [ActivityItem], activity: String?, error: String?, outgoing: [OutgoingMessage]) -> Bool {
        error == nil && outgoing.isEmpty && activity == nil
            && !status.contains { $0.running || ($0.kind == .tasks && !$0.tasks.isEmpty) }
    }

    private var running: [ActivityItem] { status.filter { $0.running && $0.kind != .tasks } }
    private var tasks: [ActivityTask] { status.last { $0.kind == .tasks }?.tasks ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let error {
                Text(error).font(.footnote).foregroundColor(.red).lineLimit(3)
                    .padding(.horizontal, AgentComposerMetrics.inner)
            }
            ForEach(running) { item in
                StackRow(label: item.label, symbol: ActivityList.symbol(for: item.kind))
            }
            // A label that is not one of the items — the road to the
            // computer, say — when nothing else is running.
            if running.isEmpty, let activity {
                StackRow(label: activity, symbol: nil)
            }
            if !tasks.isEmpty {
                TaskListRows(tasks: tasks).padding(.horizontal, AgentComposerMetrics.inner)
            }
            if !outgoing.isEmpty {
                OutgoingList(messages: outgoing, edit: edit)
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One running thing: a spinner, its kind's mark, its label on one line.
private struct StackRow: View {
    let label: String
    let symbol: String?

    var body: some View {
        HStack(spacing: AgentComposerMetrics.gap) {
            ProgressView().controlSize(.small)
            if let symbol {
                Image(systemName: symbol).foregroundColor(.secondary).font(.footnote)
            }
            Text(label).font(.footnote).foregroundColor(.secondary).lineLimit(1).truncationMode(.tail)
        }
        .padding(.horizontal, AgentComposerMetrics.inner)
        .padding(.vertical, 2)
    }
}

/// The task list as last written: what is done, what is under way, what
/// waits.
struct TaskListRows: View {
    let tasks: [ActivityTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(tasks.enumerated()), id: \.offset) { _, task in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: mark(task.state))
                        .foregroundColor(task.state == .done ? .green : .secondary)
                        .font(.footnote)
                    Text(task.title)
                        .font(.footnote)
                        .foregroundColor(task.state == .active ? .primary : .secondary)
                        .strikethrough(task.state == .done, color: .secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func mark(_ state: ActivityTask.State) -> String {
        switch state {
        case .pending: "circle"
        case .active: "circle.dotted.circle"
        case .done: "checkmark.circle.fill"
        }
    }
}
