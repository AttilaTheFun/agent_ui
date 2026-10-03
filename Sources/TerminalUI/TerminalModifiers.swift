/// Modifier keys held with a key, as SwiftTerm's key encoder numbers them
/// (the Kitty keyboard protocol's bits).
public struct TerminalModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let shift = TerminalModifiers(rawValue: 1)
    public static let option = TerminalModifiers(rawValue: 2)
    public static let control = TerminalModifiers(rawValue: 4)
    public static let command = TerminalModifiers(rawValue: 8)
}
