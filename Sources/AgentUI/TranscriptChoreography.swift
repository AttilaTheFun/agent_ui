/// What the thread keeps for its own choreography that nothing draws:
/// whether it is settling on its last row, whether the row for earlier rows
/// is in view, the row kept at the top while a page goes in, and the tasks
/// that end each of these. Out of the view's state, a change to it is not a
/// change to what is drawn: each such write cost a pass of the view (on
/// Isomer, an interpreted frame of 100–150 ms) while the thread opened.
@MainActor
final class TranscriptChoreography {
    /// Just after a thread's rows are first shown: while the list is still
    /// measuring them, each change in its height takes it to the bottom
    /// again, so it lands on the last row however long the measuring takes
    /// (a Mac's list scrolls to a row before its height is known and stops
    /// short).
    var settling = false
    /// The row that asks for earlier rows is in view.
    var earlierInView = false
    /// The row kept at the top while a page of earlier rows goes in above
    /// it: a list at its top would otherwise stay there and show the page's
    /// first row. Let go once the page has settled.
    var keptAtTop: String?
    /// When earlier rows were last asked for, and the ask put off until a
    /// page going in has settled: one page at a time, each laid out before
    /// the next is asked for, however slowly the host lays out (an
    /// interpreted one took long enough that the row asking for more stayed
    /// in view, and asked, and asked again).
    var earlierAsked: ContinuousClock.Instant?
    var earlierLater: Task<Void, Never>?
    /// The user is scrolling the thread: a finger or a trackpad on it, or
    /// the list coasting after one (never the thread's own scrolls).
    var userScrolling = false
    /// The user is typing (the view's `typing`, kept here where a task that
    /// waits reads it as it is now, not as it was when the task began).
    var typing = false
    /// When the room the thread has last changed: the keyboard on its way.
    var roomMoved: ContinuousClock.Instant?
    /// The app's latest rows, not taken while the user is busy with the
    /// thread (scrolling, typing, the keyboard moving): taken all at once a
    /// moment after they stop, so the thread never moves under them.
    var waiting: [TranscriptMessage]?
    /// The rows on screen now, by their block's id (from their appearing
    /// and disappearing): where the reader is, and the row kept in place
    /// when rows above it go.
    var onScreen: Set<String> = []
    /// The viewport as last told (TranscriptViewport), not told again
    /// unchanged.
    var toldViewport: TranscriptViewport?

    /// What ends each: one of each at a time, so a second settling or a
    /// second arrival takes over from the first instead of being cut short
    /// by it.
    var settlingEnds: Task<Void, Never>?
    var revealEnds: Task<Void, Never>?
    var keptEnds: Task<Void, Never>?
    var arrivalEnds: Task<Void, Never>?
    var pillEnds: Task<Void, Never>?
    var quietEnds: Task<Void, Never>?
    var viewportEnds: Task<Void, Never>?
}
