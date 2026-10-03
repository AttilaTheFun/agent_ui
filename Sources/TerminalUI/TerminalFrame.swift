import SwiftUI

/// What a terminal shows, as a view draws it: rows of styled runs, each run
/// a stretch of cells with one look, and where the cursor is. Built from
/// SwiftTerm's render snapshot; a value, so a view redraws when it differs.
public struct TerminalFrame: Equatable {
    public var cols: Int
    public var rows: [Row]
    public var background: Color
    public var cursor: Cursor

    /// One row of the screen.
    public struct Row: Equatable {
        public var runs: [Run]
    }

    /// Cells that look alike, side by side.
    public struct Run: Equatable {
        public var text: String
        /// How many cells it covers (a wide character covers two).
        public var cells: Int
        public var foreground: Color
        public var background: Color
        public var bold = false
        public var faint = false
        public var italic = false
        public var underline = false
        public var strikethrough = false
    }

    public struct Cursor: Equatable {
        public var col: Int
        public var row: Int
        public var visible: Bool
        public var shape: Shape
        public var color: Color

        public enum Shape: Equatable { case block, underline, bar }
    }

    /// An empty screen of this size.
    public static func blank(cols: Int, rows: Int) -> TerminalFrame {
        TerminalFrame(cols: cols, rows: Array(repeating: Row(runs: []), count: rows), background: .black,
                      cursor: Cursor(col: 0, row: 0, visible: true, shape: .block, color: .gray))
    }

    /// The text of a row, as it reads.
    public func text(ofRow index: Int) -> String {
        guard rows.indices.contains(index) else { return "" }
        return rows[index].runs.map(\.text).joined()
    }
}
