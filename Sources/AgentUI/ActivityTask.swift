import Foundation

public struct ActivityTask: Equatable, Sendable {
    public enum State: Equatable, Sendable { case pending, active, done }
    public var title: String
    public var state: State
    public init(title: String, state: State) { self.title = title; self.state = state }
}
