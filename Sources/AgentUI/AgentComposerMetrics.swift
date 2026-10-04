import SwiftUI

public enum AgentComposerMetrics {
    /// Every control along the composer's bottom row stands the same
    /// height — the capsules on the left, the round send button on the
    /// right, and anything an app puts between them — so the row reads as
    /// one line of controls rather than a jumble of sizes. A control that
    /// is a circle is this across as well.
    public static let controlHeight: CGFloat = 36
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
    /// The room around the row of controls: up to the message, and down
    /// and across to the box's edge. Each control carries it, so the send
    /// button takes taps in it — a thumb just off the circle still sends —
    /// without the box looking any different.
    static var controlsRoom: EdgeInsets { EdgeInsets(top: textInset, leading: 0, bottom: gap, trailing: gap) }
    /// The send button's fill.
    public static let sendTint = Color.indigo
    /// Stopping wears the same colour: it is the same button, saying what
    /// it can do now.
    public static let stopTint = Color.indigo
}
