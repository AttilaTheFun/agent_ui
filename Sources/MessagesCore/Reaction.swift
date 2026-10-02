/// One emoji's reactions on a message, folded: how many, and whether ours
/// is among them.
public struct Reaction: Hashable, Sendable {
    public var emoji: String
    public var count: Int
    public var mine: Bool

    public init(emoji: String, count: Int, mine: Bool) {
        self.emoji = emoji
        self.count = count
        self.mine = mine
    }
}
