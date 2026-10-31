import Observation

/// Where the reader's viewport is told (TranscriptViewport), held across a
/// view's passes as ViewAction holds its callback: one instance kept by the
/// parent, its `run` set on each of the parent's passes.
@MainActor
@Observable
public final class ViewportReport {
    @ObservationIgnored public var run: (TranscriptViewport) -> Void

    public init(run: @escaping (TranscriptViewport) -> Void = { _ in }) { self.run = run }

    public func callAsFunction(_ viewport: TranscriptViewport) { run(viewport) }
}
