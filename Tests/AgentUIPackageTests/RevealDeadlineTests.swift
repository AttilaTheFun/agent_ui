@testable import AgentUI
import XCTest

/// The hidden first rows' deadline (RevealDeadline), with the times given:
/// a settle every 200 ms, as a slow device's thread had them, never let a
/// settle run its 300 ms course, and the rows stayed hidden.
@MainActor
final class RevealDeadlineTests: XCTestCase {
    nonisolated private let start = ContinuousClock.now

    private func at(_ milliseconds: Int) -> ContinuousClock.Instant {
        start + .milliseconds(milliseconds)
    }

    func testTheDeadlineComesWhateverTheSettlesDo() {
        var deadline = RevealDeadline()
        XCTAssertNil(deadline.remaining(at: at(0)), "nothing armed before the first settle")
        XCTAssertEqual(deadline.settle(at: at(0)), .milliseconds(1500))
        // Settles every 200 ms, each sooner than one runs its course: the
        // deadline stays where the first put it.
        for time in stride(from: 200, through: 1400, by: 200) {
            XCTAssertEqual(deadline.settle(at: at(time)), .milliseconds(1500 - time), "at \(time) ms")
            XCTAssertFalse(deadline.isDue(at: at(time)))
        }
        XCTAssertEqual(deadline.settles, 8)
        XCTAssertTrue(deadline.isDue(at: at(1500)))
        // A settle once it has passed, before its task ran: due at once.
        XCTAssertEqual(deadline.settle(at: at(1600)), .zero)
        deadline.revealed()
        XCTAssertNil(deadline.settle(at: at(1800)), "nothing armed once the rows are drawn")
        XCTAssertFalse(deadline.isDue(at: at(5000)))
    }

    func testRowsDrawnSoonerAreNotDrawnAgain() {
        var deadline = RevealDeadline()
        _ = deadline.settle(at: at(0))
        // The settle ran its course: the rows were drawn at 300 ms, as on
        // any device that keeps up.
        deadline.revealed()
        XCTAssertTrue(deadline.done)
        XCTAssertNil(deadline.armed)
        XCTAssertFalse(deadline.isDue(at: at(1500)), "no deadline after an early reveal")
        // The thread settling again later (rows caught up) arms nothing.
        XCTAssertNil(deadline.settle(at: at(2000)))
        XCTAssertNil(deadline.remaining(at: at(3000)))
    }

    func testFirstRowsWhileTheUserIsBusyAreDrawnByTheDeadline() {
        let rows = [TranscriptMessage(id: "a", role: .user, text: "hi"), TranscriptMessage(id: "b", role: .assistant, text: "hello")]
        // A thread just opened, the user busy (the room moving, a touch):
        // its first rows go in at once rather than waiting, so the thread
        // settles and the deadline is armed.
        XCTAssertFalse(TranscriptView.waits(busy: true, sending: false, shown: [], revealed: false))
        // Rows still hidden under the empty state don't wait either.
        XCTAssertFalse(TranscriptView.waits(busy: true, sending: false, shown: rows, revealed: false))
        var deadline = RevealDeadline()
        XCTAssertEqual(deadline.settle(at: at(0)), .milliseconds(1500))
        // The user stays busy and nothing else settles: drawn at 1.5 s all
        // the same (the deadline asks nothing of the user).
        XCTAssertFalse(deadline.isDue(at: at(1499)))
        XCTAssertTrue(deadline.isDue(at: at(1500)))
        // Once drawn, rows wait for a busy user as before, but never a send.
        XCTAssertTrue(TranscriptView.waits(busy: true, sending: false, shown: rows, revealed: true))
        XCTAssertFalse(TranscriptView.waits(busy: true, sending: true, shown: rows, revealed: true))
        XCTAssertFalse(TranscriptView.waits(busy: false, sending: false, shown: rows, revealed: true))
    }

    func testMillisecondsForTheLog() {
        XCTAssertEqual(RevealDeadline.milliseconds(.milliseconds(1500)), 1500)
        XCTAssertEqual(RevealDeadline.milliseconds(.zero), 0)
        XCTAssertEqual(RevealDeadline.milliseconds(.microseconds(2999)), 2)
    }
}
