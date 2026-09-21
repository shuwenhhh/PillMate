import XCTest
@testable import MediStar

final class ReminderSoundChoiceTests: XCTestCase {
    func testDefaultChoiceRemainsSystemDefault() {
        XCTAssertEqual(ReminderSoundChoice.defaultChoice, .defaultSound)
        XCTAssertEqual(ReminderSoundChoice.storedChoice(""), .defaultSound)
        XCTAssertEqual(ReminderSoundChoice.storedChoice("Unknown"), .defaultSound)
    }

    func testMenuContainsAllCustomSoundsAndNone() {
        XCTAssertEqual(
            ReminderSoundChoice.allCases.map(\.rawValue),
            ["Default", "Gentle", "Star", "Soft Tap", "None"]
        )
    }

    func testCustomSoundFilesAreBundled() throws {
        for choice in [
            ReminderSoundChoice.gentle,
            ReminderSoundChoice.star,
            ReminderSoundChoice.softTap
        ] {
            let fileName = try XCTUnwrap(choice.customFileName)
            XCTAssertNotNil(
                Bundle.main.url(forResource: fileName, withExtension: nil),
                "Missing bundled reminder sound: \(fileName)"
            )
        }
    }
}
