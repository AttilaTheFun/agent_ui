// The terminal's screen: what is fed in is drawn (text, colors, the
// cursor); what is typed comes out encoded; a resize is the app's to pass
// on; starting over clears it.

@testable import TerminalUI
import SwiftUI
import XCTest

@MainActor
final class TerminalScreenTests: XCTestCase {
    private func settle() async {
        for _ in 0..<5 { await Task.yield() }
    }

    func testWhatIsFedIsDrawn() async {
        let screen = TerminalScreen(cols: 20, rows: 4)
        screen.feed(Array("hello\r\nworld".utf8))
        await settle()
        XCTAssertEqual(screen.frame.rows.count, 4)
        XCTAssertTrue(screen.frame.text(ofRow: 0).hasPrefix("hello"))
        XCTAssertTrue(screen.frame.text(ofRow: 1).hasPrefix("world"))
        XCTAssertEqual(screen.frame.cursor.row, 1)
        XCTAssertEqual(screen.frame.cursor.col, 5)
    }

    func testColorsAndStylesMakeRuns() async {
        let screen = TerminalScreen(cols: 20, rows: 2)
        screen.feed(Array("plain \u{1B}[1;31mred\u{1B}[0m".utf8))
        await settle()
        let runs = screen.frame.rows[0].runs
        let red = runs.first { $0.text == "red" }
        XCTAssertNotNil(red, "\(runs.map(\.text))")
        XCTAssertEqual(red?.bold, true)
        XCTAssertNotEqual(red?.foreground, runs.first?.foreground, "red is not the default color")
        XCTAssertEqual(runs.reduce(0) { $0 + $1.cells }, 20, "every cell is in a run")
    }

    func testTypingComesOutEncoded() {
        let screen = TerminalScreen(cols: 20, rows: 2)
        var sent: [UInt8] = []
        screen.onInput = { sent += $0 }
        screen.type("ls")
        screen.press("Enter")
        screen.press("c", modifiers: .control)
        screen.press("ArrowUp")
        XCTAssertEqual(sent, Array("ls\r".utf8) + [0x03] + Array("\u{1B}[A".utf8))
    }

    func testAPasteIsBracketedWhenAsked() {
        let screen = TerminalScreen(cols: 20, rows: 2)
        var sent: [UInt8] = []
        screen.onInput = { sent += $0 }
        screen.feed(Array("\u{1B}[?2004h".utf8))
        screen.paste("echo hi")
        XCTAssertEqual(String(decoding: sent, as: UTF8.self), "\u{1B}[200~echo hi\u{1B}[201~")
    }

    func testAResizeIsPassedOn() {
        let screen = TerminalScreen(cols: 20, rows: 4)
        var told: [String] = []
        screen.onResize = { told.append("\($0)x\($1)") }
        screen.resize(cols: 50, rows: 10)
        screen.resize(cols: 50, rows: 10)
        XCTAssertEqual(told, ["50x10"], "told once, for a real change")
        XCTAssertTrue(screen.sized)
        XCTAssertEqual(screen.frame.rows.count, 10)
        XCTAssertEqual(screen.frame.cols, 50)
    }

    /// The first size a view gives is passed on even when it is the size
    /// the screen was made with: the app needs it to take the terminal.
    func testTheFirstSizeIsAlwaysPassedOn() {
        let screen = TerminalScreen(cols: 80, rows: 24)
        var told: [String] = []
        screen.onResize = { told.append("\($0)x\($1)") }
        XCTAssertFalse(screen.sized)
        screen.resize(cols: 80, rows: 24)
        screen.resize(cols: 80, rows: 24)
        XCTAssertEqual(told, ["80x24"])
    }

    func testStartingOverClearsTheScreen() async {
        let screen = TerminalScreen(cols: 20, rows: 2)
        screen.feed(Array("old".utf8))
        await settle()
        screen.startOver()
        XCTAssertEqual(screen.frame.text(ofRow: 0).trimmingCharacters(in: .whitespaces), "")
        screen.feed(Array("new".utf8))
        await settle()
        XCTAssertTrue(screen.frame.text(ofRow: 0).hasPrefix("new"))
    }
}
