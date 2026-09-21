import UIKit
import XCTest
@testable import MediStar

final class MedicationStarStyleTests: XCTestCase {
    func testSevenStylesIncludeYellowDefault() {
        XCTAssertEqual(MedicationStarStyle.allCases.count, 7)
        XCTAssertEqual(MedicationStarStyle.defaultStyle, .yellow)
        XCTAssertEqual(MedicationStarStyle.stored("unknown"), .yellow)
    }

    func testEveryStyleHasABundledImage() {
        for style in MedicationStarStyle.allCases {
            XCTAssertNotNil(
                UIImage(named: style.assetName),
                "Missing star asset: \(style.assetName)"
            )
        }
    }

    func testMedicineEntityPersistsSelectedStyle() {
        let profile = MedicineProfile(
            name: "Vitamin D",
            dose: "10 mg",
            schedule: "8:00 AM",
            originalQuantity: 30,
            prescribedBy: "",
            purpose: "",
            instructions: "",
            starStyle: .purple
        )

        let entity = MedicineEntity(profile: profile)

        XCTAssertEqual(entity.starStyleRawValue, MedicationStarStyle.purple.rawValue)
        XCTAssertEqual(entity.profile.starStyle, .purple)
    }

    func testMedicationRecordPersistsSelectedStyle() {
        let entity = MedicationRecordEntity(
            recordDate: .now,
            medicineName: "Vitamin C",
            detail: "20 mg",
            timeWindow: "8:00 AM",
            takenAt: "8:05 AM",
            interval: "24 hours",
            starStyleRawValue: MedicationStarStyle.aqua.rawValue
        )

        XCTAssertEqual(entity.starStyleRawValue, MedicationStarStyle.aqua.rawValue)
    }
}
