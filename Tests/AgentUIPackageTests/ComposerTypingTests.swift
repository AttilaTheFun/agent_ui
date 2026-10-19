#if canImport(AppKit)
import AppKit
import SwiftUI
import XCTest
@testable import AgentUI

/// The composer's field on a Mac, typed into as a person types: AppKit's own
/// field editor, in a window that is never shown, given letters, Delete, a
/// click's caret and Shift-Return the way the keyboard gives them. Each case
/// is a bug the composer had: the caret thrown back before a letter typed
/// after a newline and a Delete, the caret thrown to the end after a
/// Shift-Return, a trap typing at the end of words with an em dash in them,
/// Delete adding a newline.
@MainActor
final class ComposerTypingTests: XCTestCase {
    @MainActor @Observable final class Draft {
        var text: String
        var picked = 0
        init(_ text: String) { self.text = text }
    }

    struct Harness: View {
        @Bindable var draft: Draft
        @FocusState private var focused: Bool
        let actions = ComposerActions()

        var body: some View {
            ComposerField(draft: $draft.text, placeholder: "Message", sentWords: nil, sending: false, focused: $focused,
                          generation: 0, attachmentCount: 0, handedOver: false, actions: actions, picked: draft.picked)
                .frame(width: 520)
        }
    }

    /// The field, hosted and focused.
    struct Field {
        let window: NSWindow
        let editor: NSTextView
        let draft: Draft
    }

    private func spin(_ seconds: Double = 0.05) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func textField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable { return field }
        for sub in view.subviews { if let found = textField(in: sub) { return found } }
        return nil
    }

    private func host(_ text: String) throws -> Field {
        let draft = Draft(text)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 400), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: Harness(draft: draft))
        window.layoutIfNeeded()
        spin(0.2)
        let textField = try XCTUnwrap(textField(in: try XCTUnwrap(window.contentView)), "no text field")
        XCTAssertTrue(window.makeFirstResponder(textField))
        spin(0.2)
        let editor = try XCTUnwrap(textField.currentEditor() as? NSTextView, "no field editor")
        return Field(window: window, editor: editor, draft: draft)
    }

    private func type(_ text: String, in field: Field) {
        for character in text {
            field.editor.insertText(String(character), replacementRange: NSRange(location: NSNotFound, length: 0))
            spin()
        }
    }

    private func delete(_ times: Int = 1, in field: Field) {
        for _ in 0..<times {
            field.editor.deleteBackward(nil)
            spin()
        }
    }

    /// Where a click puts the caret (or selects, with a length), in UTF-16
    /// offsets as AppKit counts.
    private func click(at offset: Int, length: Int = 0, in field: Field) {
        field.editor.setSelectedRange(NSRange(location: offset, length: length))
        spin()
    }

    private func shiftReturn(in field: Field) {
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .shift, timestamp: 0, windowNumber: field.window.windowNumber,
                                     context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)
        if let event { field.window.sendEvent(event) }
        spin()
    }

    /// The field's words with "|" at its caret; and the draft must say the
    /// same words.
    private func state(_ field: Field, file: StaticString = #filePath, line: UInt = #line) -> String {
        let text = field.editor.string as NSString
        XCTAssertEqual(field.draft.text, field.editor.string, "the draft and the field disagree", file: file, line: line)
        let caret = field.editor.selectedRange()
        return text.substring(to: caret.location) + "|" + text.substring(from: caret.location + caret.length)
    }

    private let paragraphs = "Also similar to how visor has \n\nAnd there is more"
    private let afterHas = 30

    /// The case reported: in the middle of a draft, "archived", Shift-Return,
    /// Delete, "d": the d goes after "archived", the caret after the d.
    func testANewlineDeletedThenALetterTyped() throws {
        let field = try host(paragraphs)
        click(at: afterHas, in: field)
        type("archived", in: field)
        shiftReturn(in: field)
        delete(in: field)
        type("d", in: field)
        XCTAssertEqual(state(field), "Also similar to how visor has archivedd|\n\nAnd there is more")
    }

    /// From the recording: "archived", Delete, "d" in the middle of a draft.
    func testALetterDeletedAndTypedAgainInTheMiddle() throws {
        let field = try host(paragraphs)
        click(at: afterHas, in: field)
        type("archived", in: field)
        delete(in: field)
        type("d", in: field)
        XCTAssertEqual(state(field), "Also similar to how visor has archived|\n\nAnd there is more")
    }

    /// Shift-Return in the middle: the newline at the caret, and the caret
    /// after it (not thrown to the end), where the next letter goes.
    func testShiftReturnInTheMiddleKeepsTheCaretAfterTheNewline() throws {
        let field = try host(paragraphs)
        click(at: afterHas, in: field)
        type("archived", in: field)
        shiftReturn(in: field)
        XCTAssertEqual(state(field), "Also similar to how visor has archived\n|\n\nAnd there is more")
        type("x", in: field)
        XCTAssertEqual(state(field), "Also similar to how visor has archived\nx|\n\nAnd there is more")
    }

    /// Typing at the end of words beyond ASCII (an em dash) trapped: the
    /// field's caret, past the draft from before the letter, was read in it.
    func testTypingAtTheEndOfWordsWithAnEmDash() throws {
        let field = try host("Visor \u{2014} the composer")
        click(at: ("Visor \u{2014} the composer" as NSString).length, in: field)
        type("xy", in: field)
        shiftReturn(in: field)
        type("z", in: field)
        XCTAssertEqual(state(field), "Visor \u{2014} the composerxy\nz|")
    }

    /// An emoji is two UTF-16 halves: a newline after one goes after both.
    func testANewlineAfterAnEmoji() throws {
        let field = try host("")
        type("a\u{1F600}", in: field)
        shiftReturn(in: field)
        type("b", in: field)
        XCTAssertEqual(state(field), "a\u{1F600}\nb|")
    }

    /// Delete never puts a newline in: newlines typed and deleted, letters
    /// between, and the words are what was typed.
    func testDeleteNeverAddsANewline() throws {
        let field = try host("start ")
        click(at: 6, in: field)
        type("a", in: field)
        shiftReturn(in: field)
        type("b", in: field)
        delete(2, in: field)
        XCTAssertEqual(state(field), "start a|")
        shiftReturn(in: field)
        shiftReturn(in: field)
        delete(2, in: field)
        type("c", in: field)
        XCTAssertEqual(state(field), "start ac|")
    }

    /// Shift-Return with words selected puts the newline in their place.
    func testShiftReturnReplacesWhatIsSelected() throws {
        let field = try host("one two three")
        click(at: 4, length: 3, in: field)
        shiftReturn(in: field)
        XCTAssertEqual(state(field), "one \n| three")
    }

    /// The caret after a picked command (the draft changed under the field,
    /// `picked` bumped): what is typed next goes after the command.
    func testTheCaretAfterAPickedCommand() throws {
        let field = try host("/com")
        click(at: 4, in: field)
        field.draft.text = "/compact "
        field.draft.picked += 1
        spin(0.2)
        type("x", in: field)
        XCTAssertEqual(state(field), "/compact x|")
    }

    /// The draft emptied under the field (a message sent): typing starts
    /// again at its start, and Shift-Return still works.
    func testTypingAfterTheDraftIsCleared() throws {
        let field = try host("")
        type("sent words", in: field)
        field.draft.text = ""
        spin(0.2)
        type("hi", in: field)
        shiftReturn(in: field)
        type("there", in: field)
        XCTAssertEqual(state(field), "hi\nthere|")
    }
}
#endif
