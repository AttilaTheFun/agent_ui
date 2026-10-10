import XCTest
@testable import AgentUI

final class AgentTests: XCTestCase {
    func testAGoalIsItsOwnRowAmongCalls() {
        let call = TranscriptMessage(id: "c", role: .assistant, text: "", activities: ["Bash: ls"])
        let goal = TranscriptMessage(id: "g", role: .tool, text: "Ship it", toolName: "goal")
        let result = TranscriptMessage(id: "r", role: .tool, text: "done", toolName: "tool_result")
        let blocks = TranscriptBlock.blocks([call, goal, result])
        XCTAssertEqual(blocks.map(\.id), ["calls-c", "g", "calls-r"])
    }

    func testBlankAndTrim() {
        XCTAssertTrue(AgentText.isBlank("  \n\t"))
        XCTAssertFalse(AgentText.isBlank(" a "))
        XCTAssertEqual(AgentText.trimmed("\n  hello world \t\n"), "hello world")
        XCTAssertEqual(AgentText.trimmed(""), "")
    }

    func testTranscriptMessageDefaults() {
        let message = TranscriptMessage(id: "1", role: .assistant, text: "hi")
        XCTAssertTrue(message.activities.isEmpty)
        XCTAssertNil(message.toolName)
        XCTAssertTrue(message.imageURLs.isEmpty)
    }
}

final class MarkdownTests: XCTestCase {
    func testBlocks() {
        let blocks = MarkdownBlocks.split("# Title\n\nSome *text* here\nmore\n\n- one\n- two\n\n```swift\nlet x = 1\n```\n1. first\n2. second")
        XCTAssertEqual(blocks.count, 5)
        if case .heading(let level, let text) = blocks[0] { XCTAssertEqual(level, 1); XCTAssertEqual(text, "Title") } else { XCTFail() }
        if case .paragraph(let text) = blocks[1] { XCTAssertEqual(text, "Some *text* here\nmore") } else { XCTFail() }
        if case .list(let items) = blocks[2] { XCTAssertEqual(items.map(\.text), ["one", "two"]); XCTAssertEqual(items[0].marker, "•") } else { XCTFail() }
        if case .code(let code, let language) = blocks[3] { XCTAssertEqual(code, "let x = 1"); XCTAssertEqual(language, "swift") } else { XCTFail() }
        if case .list(let items) = blocks[4] { XCTAssertEqual(items.map(\.marker), ["1.", "2."]) } else { XCTFail() }
    }
}

final class MarkdownQuoteTests: XCTestCase {
    /// Lines that begin with ">" are one quote, without the marker; a line
    /// without it ends the quote, and what is quoted is markdown again.
    func testQuotes() {
        let blocks = MarkdownBlocks.split("Before\n> first line\n>second line\n> - a point\n> > nested\nAfter")
        XCTAssertEqual(blocks.count, 3)
        if case .paragraph(let text) = blocks[0] { XCTAssertEqual(text, "Before") } else { XCTFail() }
        guard case .quote(let quoted) = blocks[1] else { return XCTFail() }
        XCTAssertEqual(quoted, "first line\nsecond line\n- a point\n> nested")
        let inner = MarkdownBlocks.split(quoted)
        XCTAssertEqual(inner.count, 3)
        if case .list(let items) = inner[1] { XCTAssertEqual(items.map(\.text), ["a point"]) } else { XCTFail() }
        if case .quote(let nested) = inner[2] { XCTAssertEqual(nested, "nested") } else { XCTFail() }
        if case .paragraph(let text) = blocks[2] { XCTAssertEqual(text, "After") } else { XCTFail() }
    }

    /// A ">" inside fenced code is code.
    func testAMarkerInCodeIsCode() {
        let blocks = MarkdownBlocks.split("```\n> not a quote\n```")
        if case .code(let code, _) = blocks.first { XCTAssertEqual(code, "> not a quote") } else { XCTFail() }
    }
}

final class MarkdownTableTests: XCTestCase {
    func testTable() {
        let blocks = MarkdownBlocks.split("Before\n\n| A | B |\n|---|:--|\n| 1 | 2 |\n| 3 | 4 |\n\nAfter")
        XCTAssertEqual(blocks.count, 3)
        if case .table(let header, let rows) = blocks[1] {
            XCTAssertEqual(header, ["A", "B"])
            XCTAssertEqual(rows, [["1", "2"], ["3", "4"]])
        } else { XCTFail() }
    }
}

final class InlineMarkdownTests: XCTestCase {
    func testSpans() {
        let spans = InlineMarkdown.parse("a **b** `c` [d](http://e) *f* g")
        XCTAssertEqual(spans.map(\.text), ["a ", "b", " ", "c", " ", "d", " ", "f", " g"])
        XCTAssertTrue(spans[1].bold); XCTAssertTrue(spans[3].code); XCTAssertTrue(spans[5].link); XCTAssertTrue(spans[7].italic)
    }
}

final class DraftEditTests: XCTestCase {
    func testANewlineGoesInAtTheCaret() {
        let text = "first second"
        let caret = text.index(text.startIndex, offsetBy: 5)
        let edit = DraftEdit.newline(in: text, replacing: caret..<caret)
        XCTAssertEqual(edit.text, "first\n second")
        XCTAssertEqual(edit.caret, 6)
    }

    func testANewlineReplacesWhatIsSelected() {
        let text = "first second"
        let range = text.index(text.startIndex, offsetBy: 5)..<text.index(text.startIndex, offsetBy: 6)
        let edit = DraftEdit.newline(in: text, replacing: range)
        XCTAssertEqual(edit.text, "first\nsecond")
        XCTAssertEqual(edit.caret, 6)
    }

    func testWithNoCaretKnownItGoesAtTheEnd() {
        let edit = DraftEdit.newline(in: "words", replacing: nil)
        XCTAssertEqual(edit.text, "words\n")
        XCTAssertEqual(edit.caret, 6)
    }
}
