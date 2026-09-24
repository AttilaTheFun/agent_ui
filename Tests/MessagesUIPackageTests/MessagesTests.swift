import XCTest
@testable import MessagesUI
import InboxUI
import NavigationUI

final class MessagesTests: XCTestCase {
    func testTimeLabels() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 15, minute: 0))!
        let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 9, minute: 5))!
        let thisWeek = calendar.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 12))!
        let older = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 12))!
        XCTAssertEqual(MessagesTime.label(for: today, now: now, calendar: calendar), "9:05 AM")
        XCTAssertEqual(MessagesTime.label(for: thisWeek, now: now, calendar: calendar), "Sunday")
        XCTAssertEqual(MessagesTime.label(for: older, now: now, calendar: calendar), "8/1/26")
    }

    func testSummaryDefaultsAvatarToInitial() {
        let summary = ConversationSummary(id: "a", name: "Ada")
        XCTAssertEqual(summary.avatar, .initial("Ada"))
        XCTAssertEqual(summary.presence, .hidden)
    }

    func testMacHangGeometry() {
        // 8pt from the top, a 40pt avatar overlapping a 27pt pill by 5, minus the 52pt bar.
        XCTAssertEqual(ConversationTitle.macHang, 18)
    }
}
