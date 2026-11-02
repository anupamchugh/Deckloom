import XCTest
@testable import Deckloom

final class DeckloomTests: XCTestCase {
    func testSwipeSnapsOneCardAndClampsAtEnds() {
        XCTAssertEqual(DeckSelection.target(current: 1, count: 4, predictedTranslation: -150, threshold: 50), 2)
        XCTAssertEqual(DeckSelection.target(current: 1, count: 4, predictedTranslation: 150, threshold: 50), 0)
        XCTAssertEqual(DeckSelection.target(current: 3, count: 4, predictedTranslation: -500, threshold: 50), 3)
        XCTAssertEqual(DeckSelection.target(current: 0, count: 4, predictedTranslation: 500, threshold: 50), 0)
        XCTAssertEqual(DeckSelection.target(current: 1, count: 4, predictedTranslation: 10, threshold: 50), 1)
    }
}
