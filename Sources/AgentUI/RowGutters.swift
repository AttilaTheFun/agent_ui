import Observation
import SwiftUI

/// How much narrower than the transcript's list its rows are, on each side:
/// a Mac's list keeps room beside its rows (its scroller's, its table's),
/// which no other platform's does. The composer takes the same insets, so
/// it lines up under the rows rather than under the whole list.
@MainActor
@Observable
final class RowGutters {
    var leading: CGFloat = 0
    var trailing: CGFloat = 0

    /// From the list's frame and a row's, both in the window: whole points,
    /// and only a change written.
    func measure(list: CGRect, row: CGRect) {
        guard list.width > 0, row.width > 0 else { return }
        let leading = max(0, (row.minX - list.minX).rounded()), trailing = max(0, (list.maxX - row.maxX).rounded())
        if leading != self.leading { self.leading = leading }
        if trailing != self.trailing { self.trailing = trailing }
    }
}
