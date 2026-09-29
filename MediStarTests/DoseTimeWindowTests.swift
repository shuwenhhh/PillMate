import XCTest
@testable import MediStar

final class DoseTimeWindowTests: XCTestCase {
    func testDefaultTwoHourBufferCreatesExpectedWindow() {
        XCTAssertEqual(
            DoseTimeWindow.display(schedule: "8:00 AM", bufferHours: DoseTimeWindow.defaultHours),
            "8:00–10:00 AM"
        )
    }

    func testLegacyNoBufferSettingUsesDefaultWindow() {
        XCTAssertEqual(DoseTimeWindow.choiceLabel(for: 0), "2 hours")
        XCTAssertEqual(
            DoseTimeWindow.display(schedule: "8:00 AM", bufferHours: 0),
            "8:00–10:00 AM"
        )
    }

    func testDoseAtEndOfBufferIsOnTime() {
        XCTAssertEqual(
            DoseTimeWindow.relation(takenAt: "10:00 AM", schedule: "8:00 AM", bufferHours: 2),
            .onTime
        )
    }

    func testDoseAfterBufferIsLate() {
        XCTAssertEqual(
            DoseTimeWindow.relation(takenAt: "10:01 AM", schedule: "8:00 AM", bufferHours: 2),
            .late
        )
    }

    func testDoseBeforeScheduledTimeIsEarly() {
        XCTAssertEqual(
            DoseTimeWindow.relation(takenAt: "7:59 AM", schedule: "8:00 AM", bufferHours: 2),
            .early
        )
    }

    func testWindowCanCrossMidnight() {
        XCTAssertEqual(
            DoseTimeWindow.display(schedule: "11:00 PM", bufferHours: 2),
            "11:00 PM–1:00 AM"
        )
        XCTAssertEqual(
            DoseTimeWindow.relation(takenAt: "12:30 AM", schedule: "11:00 PM", bufferHours: 2),
            .onTime
        )
    }

    func testExplicitWindowIsNotExtendedAgain() {
        XCTAssertEqual(
            DoseTimeWindow.display(schedule: "8:00–10:00 AM", bufferHours: 4),
            "8:00–10:00 AM"
        )
        XCTAssertEqual(
            DoseTimeWindow.relation(takenAt: "10:30 AM", schedule: "8:00–10:00 AM", bufferHours: 4),
            .late
        )
    }

    func testScheduledMinutesAreSharedAcrossSingleTimesAndRanges() {
        XCTAssertEqual(
            DoseTimeWindow.scheduledMinutes(in: "8:00 AM · 8:00 PM"),
            [8 * 60, 20 * 60]
        )
        XCTAssertEqual(
            DoseTimeWindow.scheduledMinutes(in: "8:00–10:00 AM"),
            [8 * 60]
        )
        XCTAssertEqual(DoseTimeWindow.scheduledMinutes(in: "As needed"), [])
    }
}
