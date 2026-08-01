import Testing

@testable import KoikoiCore

@Suite struct CardTests {
    @Test func monthFlowerNames() {
        let expected = ["松", "梅", "桜", "藤", "菖蒲", "牡丹", "萩", "芒", "菊", "紅葉", "柳", "桐"]
        for (month, name) in zip(Month.allCases, expected) {
            #expect(month.flowerName == name)
        }
    }

    @Test func monthOldNames() {
        let expected = [
            "睦月", "如月", "弥生", "卯月", "皐月", "水無月",
            "文月", "葉月", "長月", "神無月", "霜月", "師走"
        ]
        for (month, name) in zip(Month.allCases, expected) {
            #expect(month.oldName == name)
        }
    }

    @Test func allCardsCount() {
        #expect(Card.all.count == 48)
    }

    /// ID は配列位置と一致する（セーブデータ互換のため go-koikoi と同一並び）。
    @Test func allCardsIDs() {
        for (index, card) in Card.all.enumerated() {
            #expect(card.id == index)
        }
    }

    @Test func monthDistribution() {
        for month in Month.allCases {
            #expect(Card.all.count(where: { $0.month == month }) == 4)
        }
    }

    @Test func typeDistribution() {
        #expect(Card.all.count(where: { $0.type == .hikari }) == 5)
        #expect(Card.all.count(where: { $0.type == .tane }) == 9)
        #expect(Card.all.count(where: { $0.type == .tanzaku }) == 10)
        #expect(Card.all.count(where: { $0.type == .kasu }) == 24)
    }

    @Test func cardDisplay() {
        #expect(Card.all[0].name == "松に鶴")
        #expect(Card.all[0].display == "[松:光]")
        #expect(Card.all[28].display == "[芒:光]")
        #expect(Card.all[43].display == "[柳:カ]")
    }

    @Test func cardByID() {
        #expect(Card.card(id: 0)?.name == "松に鶴")
        #expect(Card.card(id: 47)?.name == "桐のカス３")
        #expect(Card.card(id: 48) == nil)
        #expect(Card.card(id: -1) == nil)
    }
}
