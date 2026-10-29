import Observation

/// A callback about one of the thread's messages, by its id, held across
/// passes as `ViewAction` is: the rows it is handed to compare equal while
/// it is the same instance.
@MainActor
@Observable
final class MessageAction {
    @ObservationIgnored var run: (String) -> Void

    init(run: @escaping (String) -> Void = { _ in }) { self.run = run }

    func callAsFunction(_ id: String) { run(id) }
}
