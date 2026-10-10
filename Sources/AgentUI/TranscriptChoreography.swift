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

    /// What ends each: one of each at a time, so a second settling or a
    /// second arrival takes over from the first instead of being cut short
    /// by it.
    var settlingEnds: Task<Void, Never>?
    var revealEnds: Task<Void, Never>?
    var keptEnds: Task<Void, Never>?
    var arrivalEnds: Task<Void, Never>?
    var pillEnds: Task<Void, Never>?
}
