import Foundation
import SwiftUI
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

final class NewRowsTests: XCTestCase {
    private func row(_ id: String, _ role: TranscriptMessage.Role = .assistant, calls: [String] = []) -> TranscriptMessage {
        TranscriptMessage(id: id, role: role, text: calls.isEmpty ? id : "", activities: calls)
    }

    /// The pill counts rows after the last there was, as drawn: a run of
    /// tool calls is one row, and a call joining the run is none.
    func testRowsAfterTheLastAreCounted() {
        let old = [row("a", .user), row("b")]
        XCTAssertEqual(TranscriptView.newRows(in: old + [row("c", calls: ["Bash: ls"]), row("d", calls: ["Bash: pwd"]), row("e")], after: old), 2)
        let withRun = old + [row("c", calls: ["Bash: ls"])]
        XCTAssertEqual(TranscriptView.newRows(in: withRun + [row("d", calls: ["Bash: pwd"])], after: withRun), 0)
    }

    /// Earlier rows put in above are not new; rows that replace all the
    /// old are not counted.
    func testEarlierOrReplacedRowsAreNotCounted() {
        let old = [row("c"), row("d")]
        XCTAssertEqual(TranscriptView.newRows(in: [row("a"), row("b")] + old, after: old), 0)
        XCTAssertEqual(TranscriptView.newRows(in: [row("x"), row("y")], after: old), 0)
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
        let edit = DraftEdit.newline(in: "first second", replacing: (5, 5))
        XCTAssertEqual(edit.text, "first\n second")
        XCTAssertEqual(edit.caret, 6)
    }

    func testANewlineReplacesWhatIsSelected() {
        let edit = DraftEdit.newline(in: "first second", replacing: (5, 6))
        XCTAssertEqual(edit.text, "first\nsecond")
        XCTAssertEqual(edit.caret, 6)
    }

    func testWithNoCaretKnownItGoesAtTheEnd() {
        let edit = DraftEdit.newline(in: "words", replacing: nil)
        XCTAssertEqual(edit.text, "words\n")
        XCTAssertEqual(edit.caret, 6)
    }

    /// Offsets are UTF-16, as a field's are: after an em dash and an emoji
    /// the newline still goes where the caret is.
    func testANewlineAfterWordsBeyondASCII() {
        let text = "a \u{2014} \u{1F600} b"
        let caret = ("a \u{2014} \u{1F600}" as String).utf16.count
        let edit = DraftEdit.newline(in: text, replacing: (caret, caret))
        XCTAssertEqual(edit.text, "a \u{2014} \u{1F600}\n b")
        XCTAssertEqual(edit.caret, caret + 1)
    }

    /// A caret inside an emoji (between its two UTF-16 halves) is moved
    /// back to its start, not split.
    func testACaretInsideACharacterGoesBackToItsStart() {
        let text = "x\u{1F600}y"
        let edit = DraftEdit.newline(in: text, replacing: (2, 2))
        XCTAssertEqual(edit.text, "x\n\u{1F600}y")
    }
}

@MainActor
final class DraftCaretTests: XCTestCase {
    /// The caret the field gave for the words before a correction is not
    /// handed back with the corrected words, where it would be a letter
    /// short of the end.
    func testACaretIsOnlyForTheWordsItWasGivenFor() {
        let typed = "i dont "
        let caret = DraftCaret.end(of: typed)
        XCTAssertEqual(caret.selection(in: typed), DraftSelection(insertionPoint: typed.endIndex))
        XCTAssertNil(caret.selection(in: "i don\u{2019}t "))
    }

    /// A caret the field said before its words (a Mac's, as a key is
    /// typed) is given back to the field only once it has its words, and is
    /// the newline's caret meanwhile.
    func testACaretWithoutItsWordsYetIsTheNewlinesButNotTheFields() {
        let caret = DraftCaret(lower: 6, upper: 6, text: nil)
        XCTAssertNil(caret.selection(in: "first, second"))
        XCTAssertEqual(caret.range(in: "first, second")?.lower, 6)
    }

    /// The field's index, read in the words it is in, as a UTF-16 offset:
    /// a Mac's field's (UTF-16) and a Swift string's (UTF-8) alike.
    func testAFieldsIndexIsReadInItsWords() {
        let accents = String(repeating: "\u{00E9}", count: 9000)
        // Foundation's own words, as a field has them: UTF-16 indices.
        let bridged = NSString(characters: Array(accents.utf16), length: accents.utf16.count) as String
        let utf16Index = bridged.utf16.index(bridged.utf16.startIndex, offsetBy: 8500)
        XCTAssertTrue(utf16Index.debugDescription.hasSuffix("[utf16]"), utf16Index.debugDescription)
        XCTAssertEqual(DraftCaret.reported(DraftSelection(insertionPoint: utf16Index), in: accents)?.lower, 8500)
        let utf8Index = accents.index(accents.startIndex, offsetBy: 8500)
        XCTAssertEqual(DraftCaret.reported(DraftSelection(insertionPoint: utf8Index), in: accents)?.lower, 8500)
    }

    /// A caret past the end of the words it is read in (the field's, for
    /// longer words than the draft has) is none, and does not trap — as it
    /// did, reading a Mac's caret against the draft from before the letter
    /// typed.
    func testACaretPastTheWordsIsNoneAndDoesNotTrap() {
        let words = "\u{2014} and on and on"
        let longer = NSString(characters: Array(words.utf16), length: words.utf16.count) as String
        let end = longer.utf16.index(longer.utf16.startIndex, offsetBy: longer.utf16.count)
        XCTAssertNil(DraftCaret.reported(DraftSelection(insertionPoint: end), in: "\u{2014} and"))
    }
}
