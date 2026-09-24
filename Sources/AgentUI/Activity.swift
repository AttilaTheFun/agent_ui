// What a turn is doing, as streamed — none of it the record. One item per
// thing: the model thinking, a shell running, a monitor watching, a
// subagent working, a tool called, the task list as it stands. Running
// until its result comes, then settled; gone when the turn ends.

import Foundation

public struct ActivityItem: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case thinking, shell, monitor, subagent, tool, tasks }
    public var id: String
    public var kind: Kind
    public var label: String
    public var running: Bool
    /// For `.tasks`: the list as last written.
    public var tasks: [ActivityTask]

    public init(id: String, kind: Kind, label: String, running: Bool, tasks: [ActivityTask] = []) {
        self.id = id; self.kind = kind; self.label = label; self.running = running; self.tasks = tasks
    }
}

public struct ActivityTask: Equatable, Sendable {
    public enum State: Equatable, Sendable { case pending, active, done }
    public var title: String
    public var state: State
    public init(title: String, state: State) { self.title = title; self.state = state }
}
