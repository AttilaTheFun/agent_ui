import Observation
import SwiftUI

/// How much narrower the transcript's rows are than the space the composer
/// is laid out in: a Mac's list keeps room on the trailing side of its rows
/// (its scroller's, its table's) that the composer's bar doesn't. The
/// composer keeps the same room, so it lines up under the rows. Widths, not
/// positions: Isomer places a list's rows in the window differently from
/// SwiftUI (on a phone on its side, past the notch's safe area), while
/// their widths agree; and on a phone on its side the rows and the bar both
/// keep to the safe area, so there is nothing to add.
@MainActor
@Observable
final class RowGutters {
    var trailing: CGFloat = 0

    /// A row's whole width and the composer bar's.
    @ObservationIgnored var row: CGFloat = 0 {
        didSet { if row != oldValue { measure() } }
    }
    @ObservationIgnored var bar: CGFloat = 0 {
        didSet { if bar != oldValue { measure() } }
    }

    /// Whole points, and only a change written.
    private func measure() {
        guard row > 0, bar > 0 else { return }
        let trailing = max(0, (bar - row).rounded())
        if trailing != self.trailing { self.trailing = trailing }
    }
}
