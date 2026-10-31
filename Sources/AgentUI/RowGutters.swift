import Observation
import SwiftUI

/// How much narrower the transcript's rows are than the space the composer
/// is laid out in, on each side: a Mac's list keeps room beside its rows
/// (its scroller's, its table's) that the composer's bar doesn't. The
/// composer takes the same insets, so it lines up under the rows. Measured
/// against the bar, not the list: on a phone on its side the list reaches
/// under the notch while its rows and the bar both keep to the safe area,
/// and there is nothing to add.
@MainActor
@Observable
final class RowGutters {
    var leading: CGFloat = 0
    var trailing: CGFloat = 0

    /// A row's whole width and the composer bar's, in the window.
    @ObservationIgnored var row: CGRect = .zero {
        didSet { if row != oldValue { measure() } }
    }
    @ObservationIgnored var bar: CGRect = .zero {
        didSet { if bar != oldValue { measure() } }
    }

    /// Whole points, and only a change written.
    private func measure() {
        guard row.width > 0, bar.width > 0 else { return }
        let leading = max(0, (row.minX - bar.minX).rounded()), trailing = max(0, (bar.maxX - row.maxX).rounded())
        if leading != self.leading { self.leading = leading }
        if trailing != self.trailing { self.trailing = trailing }
    }
}
