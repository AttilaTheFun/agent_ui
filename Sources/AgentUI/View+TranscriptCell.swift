import SwiftUI

extension View {
    /// A list whose rows are exactly as tall as what is in them. A List
    /// gives every row a minimum height (44pt on a phone), which turned an
    /// empty scroll-target row into a blank band under the transcript.
    func noMinimumRowHeight() -> some View {
        environment(\.defaultMinListRowHeight, 0)
    }

    /// One transcript row: the stack's 12pt spacing as 6pt above and
    /// below, and the reading width kept on a wide display.
    func transcriptCell() -> some View {
        self
            .padding(.vertical, 6)
            // Two frames with different jobs. The inner one holds the row
            // to the column's width, leading, so a row narrower than the
            // column (an activity line, a lone tool call) sits at the left
            // edge with the rest, not centred in the slack. The outer one
            // centres that column in a window wider than it, so the thread
            // sits in the middle — and lines up with the composer, which
            // centres the same way.
            .frame(maxWidth: TranscriptMetrics.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
    }

    /// A row with nothing of the list's own around it: no insets, no
    /// background.
    func plainListRow() -> some View {
        listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
    }
}
