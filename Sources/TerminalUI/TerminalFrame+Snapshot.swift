import SwiftTerm
import SwiftUI

extension TerminalFrame {
    /// The frame for a snapshot of SwiftTerm's screen: each row's cells
    /// grouped into runs by how they look, colors resolved against the
    /// terminal's palette and default pair, as SwiftTerm's own views do.
    init(_ snapshot: TerminalRenderSnapshot) {
        let foreground = snapshot.reverseVideo ? snapshot.backgroundColor : snapshot.foregroundColor
        let background = snapshot.reverseVideo ? snapshot.foregroundColor : snapshot.backgroundColor
        func resolve(_ color: Attribute.Color, isForeground: Bool, bold: Bool) -> SwiftUI.Color {
            switch color {
            case .defaultColor:
                return Self.color(isForeground ? foreground : background)
            case .defaultInvertedColor:
                return Self.color(isForeground ? background : foreground)
            case .ansi256(let code):
                // Bold makes the first colors bright, as SwiftTerm's views do.
                let index = code < 7 && bold ? Int(code) + 8 : Int(code)
                guard snapshot.palette.indices.contains(index) else { return Self.color(isForeground ? foreground : background) }
                return Self.color(snapshot.palette[index])
            case .trueColor(let red, let green, let blue):
                return SwiftUI.Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
            }
        }
        var rows: [Row] = []
        rows.reserveCapacity(snapshot.lines.count)
        for line in snapshot.lines {
            var runs: [Run] = []
            for cell in line.cells {
                // The second half of a wide character is drawn by the first.
                if cell.width == 0 || cell.widthState == .spacerTail { continue }
                let style = cell.attribute.style
                var fg = cell.attribute.fg
                var bg = cell.attribute.bg
                if style.contains(.inverse) {
                    swap(&fg, &bg)
                    if fg == .defaultColor { fg = .defaultInvertedColor }
                    if bg == .defaultColor { bg = .defaultInvertedColor }
                }
                let bold = style.contains(.bold)
                let back = resolve(bg, isForeground: false, bold: false)
                let front = style.contains(.invisible) ? back : resolve(fg, isForeground: true, bold: bold)
                let text = cell.text.isEmpty ? " " : cell.text
                let width = max(1, Int(cell.width))
                let underlined = style.contains(.underline) || cell.attribute.underlineStyle != .none
                if var last = runs.last, last.foreground == front, last.background == back, last.bold == bold,
                   last.faint == style.contains(.dim), last.italic == style.contains(.italic),
                   last.underline == underlined, last.strikethrough == style.contains(.crossedOut) {
                    last.text += text
                    last.cells += width
                    runs[runs.count - 1] = last
                } else {
                    runs.append(Run(text: text, cells: width, foreground: front, background: back, bold: bold,
                                    faint: style.contains(.dim), italic: style.contains(.italic),
                                    underline: underlined, strikethrough: style.contains(.crossedOut)))
                }
            }
            rows.append(Row(runs: runs))
        }
        let shape: Cursor.Shape
        switch snapshot.cursor.style {
        case .blinkBlock, .steadyBlock: shape = .block
        case .blinkUnderline, .steadyUnderline: shape = .underline
        case .blinkBar, .steadyBar: shape = .bar
        }
        self.init(cols: snapshot.cols, rows: rows, background: Self.color(background),
                  cursor: Cursor(col: snapshot.cursor.x, row: snapshot.cursor.y, visible: !snapshot.cursor.hidden, shape: shape,
                                 color: Self.color(snapshot.cursorColor ?? foreground)))
    }

    /// SwiftTerm's sixteen-bit color as SwiftUI's.
    static func color(_ color: SwiftTerm.Color) -> SwiftUI.Color {
        SwiftUI.Color(red: Double(color.red) / 65535, green: Double(color.green) / 65535, blue: Double(color.blue) / 65535)
    }
}
