import SwiftUI

/// A markdown table: a bold header row, hairlines between rows, columns
/// sharing the width. Long tables scroll sideways rather than squeeze.
struct MarkdownTable: View {
    let header: [String]
    let rows: [[String]]
    let inline: (String) -> Text

    var body: some View {
        // One grid, so the columns line up down the table; a long cell
        // wraps and its row grows, rather than the table running off the
        // side.
        Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 0) {
            GridRow { cells(header, bold: true) }
            Rectangle().fill(Color.secondary.opacity(0.4)).frame(height: 1)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                GridRow { cells(row, bold: false) }
                if index < rows.count - 1 {
                    Rectangle().fill(Color.secondary.opacity(0.15)).frame(height: 1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private func cells(_ cells: [String], bold: Bool) -> some View {
        ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
            inline(cell)
                .font(bold ? .subheadline.weight(.semibold) : .subheadline)
                // Wrapped, not cut to a line: Apple's grid otherwise
                // truncates a long cell.
                .fixedSize(horizontal: false, vertical: true)
                // The last column takes the width left over, so a row is
                // measured at the width it is drawn at.
                .frame(maxWidth: index == cells.count - 1 ? .infinity : nil, alignment: .leading)
                // On each cell: a row's own padding does not reach every
                // renderer.
                .padding(.vertical, 5)
        }
    }
}
