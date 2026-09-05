import Testing

@testable import KoikoiCore

@Suite struct CardTests {
    @Test func monthFlowerNames() {
        let expected = [
            "Pine", "Plum", "Cherry Blossom", "Wisteria", "Iris", "Peony",
            "Bush Clover", "Pampas Grass", "Chrysanthemum", "Maple", "Willow", "Paulownia"
        ]
        for (month, name) in zip(Month.allCases, expected) {
            #expect(month.flowerName == name)
        }
    }

    @Test func monthNames() {
        let expected = [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        ]
        for (month, name) in zip(Month.allCases, expected) {
            #expect(month.monthName == name)
        }
    }

    @Test func cardTypeNames() {
        #expect(CardType.hikari.name == "Brights")
        #expect(CardType.tanzaku.name == "Ribbons")
        #expect(CardType.tane.name == "Animals")
        #expect(CardType.kasu.name == "Chaff")
    }

    /// 48 枚の英語名が重複しない（String Catalog のキーになるため）。
    @Test func cardNamesAreUnique() {
        #expect(Set(Card.all.map(\.name)).count == 48)
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
        #expect(Card.all[0].name == "Pine and Crane")
        #expect(Card.all[0].display == "[Pine:Brights]")
        #expect(Card.all[28].display == "[Pampas Grass:Brights]")
        #expect(Card.all[43].display == "[Willow:Chaff]")
    }

    @Test func cardByID() {
        #expect(Card.card(id: 0)?.name == "Pine and Crane")
        #expect(Card.card(id: 47)?.name == "Paulownia Chaff 3")
        #expect(Card.card(id: 48) == nil)
        #expect(Card.card(id: -1) == nil)
    }
}
