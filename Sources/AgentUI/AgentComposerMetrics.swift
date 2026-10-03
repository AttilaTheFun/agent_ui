import SwiftUI

public enum AgentComposerMetrics {
    /// Every control along the composer's bottom row stands the same
    /// height — the capsules on the left, the round send button on the
    /// right, and anything an app puts between them — so the row reads as
    /// one line of controls rather than a jumble of sizes. A control that
    /// is a circle is this across as well.
    public static let controlHeight: CGFloat = 36
    /// How far past its circle the send (or stop) button still takes a
    /// tap: into the box's padding and the space around it, so a thumb
    /// that lands just off the circle still sends.
    static let hitSlop = EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 12)
    /// The one gap in the composer: from the box's edges, between the
    /// controls, and between them and the message. The space between the
    /// last control and the send button is the exception — it is whatever
    /// is left.
    public static let gap: CGFloat = 8
    /// What the message itself sits in from: the box's top and sides, and
    /// the row of controls below it. Wider than `gap`, because a line of
    /// text wants more air around it than a capsule does.
    public static let textInset: CGFloat = 12
    /// The message's own padding, on top of the box's: together they make
    /// `textInset`.
    static var inner: CGFloat { textInset - gap }
    /// The send button's fill.
    public static let sendTint = Color.indigo
    /// Stopping wears the same colour: it is the same button, saying what
    /// it can do now.
    public static let stopTint = Color.indigo
}
