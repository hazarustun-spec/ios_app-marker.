import XCTest
import SwiftUI
@testable import AINewsApp

final class CardToneTests: XCTestCase {

    // Topic ID → CardTone eşleşmesi (UI rengi)
    func test_cardTone_forKnownTopics() {
        XCTAssertEqual(CardTone.forTopicId("llms").background.description,
                       CardTone.mint.background.description)
        XCTAssertEqual(CardTone.forTopicId("safety").background.description,
                       CardTone.mint.background.description)
        XCTAssertEqual(CardTone.forTopicId("robotics").background.description,
                       CardTone.sage.background.description)
        XCTAssertEqual(CardTone.forTopicId("policy").background.description,
                       CardTone.sage.background.description)
        XCTAssertEqual(CardTone.forTopicId("research").background.description,
                       CardTone.cream.background.description)
        XCTAssertEqual(CardTone.forTopicId("tools").background.description,
                       CardTone.cream.background.description)
    }

    // Bilinmeyen ID için fallback
    func test_cardTone_unknownTopic_fallsBackToCream() {
        XCTAssertEqual(CardTone.forTopicId("nonexistent").background.description,
                       CardTone.cream.background.description)
    }

    // Hex parser doğruluğu
    func test_colorHex_parsesCorrectly() {
        let mint = Color(hex: "#C8DC92")
        let black = Color(hex: "#0E0E0E")
        XCTAssertNotNil(mint)
        XCTAssertNotNil(black)
        // Renkler birbirinden farklı olmalı
        XCTAssertNotEqual(mint.description, black.description)
    }

    // 3 karakterli hex (kısa form) parser
    func test_colorHex_threeChar() {
        let red = Color(hex: "#F00")
        XCTAssertNotNil(red)
    }
}
