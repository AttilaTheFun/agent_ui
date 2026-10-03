import SwiftTerm

/// What the terminal sends back toward the program it draws for — answers
/// to its queries and the bytes typed keys encode to — kept until the
/// screen collects them. SwiftTerm calls `send` while it holds its lock,
/// so this only queues.
final class TerminalOutlet: TerminalDelegate {
    private(set) var pending: [UInt8] = []

    func send(source: Terminal, data: ArraySlice<UInt8>) {
        pending.append(contentsOf: data)
    }

    /// What was queued since the last time, and nothing after.
    func take() -> [UInt8] {
        defer { pending = [] }
        return pending
    }
}
