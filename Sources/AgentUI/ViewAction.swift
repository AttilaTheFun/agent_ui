import Observation

/// A callback held across a view's passes. A closure never compares equal,
/// so a view given one is evaluated again whenever its parent is, even when
/// nothing it shows changed; given this instead — one instance kept by the
/// parent, its `run` set on each of the parent's passes — it compares by
/// identity (as SwiftUI and Isomer compare an observable model), and is
/// passed over when nothing else it was given changed.
@MainActor
@Observable
public final class ViewAction {
    @ObservationIgnored public var run: () -> Void

    public init(run: @escaping () -> Void = {}) { self.run = run }

    public func callAsFunction() { run() }
}
