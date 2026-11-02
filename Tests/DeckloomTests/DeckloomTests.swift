import SwiftUI
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

    func testOnlySidewaysDragsChangeCards() {
        XCTAssertTrue(DeckSelection.isHorizontal(CGSize(width: -120, height: 30)))
        XCTAssertFalse(DeckSelection.isHorizontal(CGSize(width: 20, height: -200)), "a scroll that starts on a card")
        XCTAssertFalse(DeckSelection.isHorizontal(CGSize(width: 40, height: 40)))
    }

    func testSelectionFallsBackToFirstCard() {
        let ids = ["a", "b", "c"]
        XCTAssertEqual(DeckSelection.index(of: "c", in: ids), 2)
        XCTAssertEqual(DeckSelection.index(of: nil, in: ids), 0)
        XCTAssertEqual(DeckSelection.index(of: "gone", in: ids), 0)
        XCTAssertEqual(DeckSelection.index(of: "a", in: [String]()), 0)
    }

    func testTapOpensFrontCardAndSelectsNeighbor() {
        XCTAssertEqual(DeckSelection.tap(1, selected: 1), .open)
        XCTAssertEqual(DeckSelection.tap(2, selected: 1), .select)
        XCTAssertEqual(DeckSelection.tap(0, selected: 1), .select)
    }

    func testFanSpreadsNeighborsWiderThanStack() {
        let stacked = DeckPlacement(distance: 1, isFanned: false, cardWidth: 300)
        let fanned = DeckPlacement(distance: 1, isFanned: true, cardWidth: 300)
        XCTAssertEqual(stacked, DeckPlacement(distance: 1, isFanned: false, cardWidth: 100), "a stack ignores card width")
        XCTAssertGreaterThan(fanned.x, stacked.x)
        XCTAssertGreaterThan(fanned.rotation, stacked.rotation)
        XCTAssertEqual(fanned.x, 96)
    }

    func testFrontCardIsCenteredAndOnTop() {
        for isFanned in [false, true] {
            let front = DeckPlacement(distance: 0, isFanned: isFanned, cardWidth: 300)
            XCTAssertEqual(front, DeckPlacement(distance: 0, isFanned: !isFanned, cardWidth: 300))
            XCTAssertEqual(front.x, 0)
            XCTAssertEqual(front.rotation, 0)
            let left = DeckPlacement(distance: -2, isFanned: isFanned, cardWidth: 300)
            let right = DeckPlacement(distance: 2, isFanned: isFanned, cardWidth: 300)
            XCTAssertGreaterThan(front.zIndex, left.zIndex)
            XCTAssertEqual(left.x, -right.x, "neighbors mirror each other")
            XCTAssertEqual(left.y, right.y)
        }
    }

    func testPileShowsSelectedCardAndUpToTwoAfterIt() {
        let ids = ["a", "b", "c", "d"]
        XCTAssertEqual(DeckPile.shown(ids, from: nil), 0..<3)
        XCTAssertEqual(DeckPile.shown(ids, from: "c"), 2..<4)
        XCTAssertEqual(DeckPile.shown(ids, from: "d"), 3..<4)
        XCTAssertEqual(DeckPile.shown([String](), from: nil), 0..<0)
        XCTAssertNotEqual(DeckPile.rotation(depth: 0), DeckPile.rotation(depth: 1), "the pile looks rotated")
    }

    func testOpeningPileResolvesSelection() {
        let ids = ["a", "b", "c"]
        XCTAssertEqual(DeckPile.openingSelection(nil, in: ids), "a")
        XCTAssertEqual(DeckPile.openingSelection("gone", in: ids), "a")
        XCTAssertEqual(DeckPile.openingSelection("b", in: ids), "b")
        XCTAssertNil(DeckPile.openingSelection(nil, in: [String]()))
    }

    func testTapZonesGoBackAndForward() {
        XCTAssertEqual(DeckPaging.leadingShare, 1.0 / 3)
        XCTAssertEqual(DeckPaging.tap(.leading, current: 2, count: 4), .show(1))
        XCTAssertEqual(DeckPaging.tap(.leading, current: 0, count: 4), .show(0), "back stops at the first card")
        XCTAssertEqual(DeckPaging.tap(.trailing, current: 2, count: 4), .show(3))
        XCTAssertEqual(DeckPaging.tap(.trailing, current: 3, count: 4), .close, "forward from the last card closes")
    }

    func testProgressFillsSeenAndCurrentCards() {
        XCTAssertTrue(DeckPaging.isFilled(0, current: 1))
        XCTAssertTrue(DeckPaging.isFilled(1, current: 1))
        XCTAssertFalse(DeckPaging.isFilled(2, current: 1))
    }

    func testSelectionCarriesThroughOpenPageAndClose() {
        let ids = ["a", "b", "c", "d"]
        var selection = DeckPile.openingSelection(nil as String?, in: ids)
        for _ in 0..<2 {
            guard case .show(let index) = DeckPaging.tap(.trailing, current: DeckSelection.index(of: selection, in: ids), count: ids.count)
            else { return XCTFail("expected another card") }
            selection = ids[index]
        }
        XCTAssertEqual(selection, "c")
        XCTAssertEqual(DeckPile.shown(ids, from: selection), 2..<4, "the closed pile starts where the deck stopped")
    }

    func testReduceMotionCrossFadesInsteadOfFlying() {
        XCTAssertTrue(DeckMotion.flies(reduceMotion: false))
        XCTAssertFalse(DeckMotion.flies(reduceMotion: true))
        XCTAssertEqual(DeckMotion.animation(reduceMotion: true), .easeInOut(duration: 0.2))
        XCTAssertNotEqual(DeckMotion.animation(reduceMotion: false), DeckMotion.animation(reduceMotion: true))
    }
}
