import XCTest
@testable import AgentUI

final class AgentTests: XCTestCase {
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
