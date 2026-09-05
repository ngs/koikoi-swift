import Foundation

/// 月（花の種類）。ngs/go-koikoi の `Month` に対応する。
public enum Month: Int, CaseIterable, Sendable, Codable, Hashable {
    case january, february, march, april, may, june
    case july, august, september, october, november, december

    /// 花の名前（英語。日本語訳は UI 層の String Catalog が持つ: 松・梅・桜…）
    public var flowerName: String {
        Self.flowerNames[rawValue]
    }

    /// 月の名前（英語。日本語訳は旧暦名 睦月・如月…）
    public var monthName: String {
        Self.monthNames[rawValue]
    }

    private static let flowerNames = [
        "Pine", "Plum", "Cherry Blossom", "Wisteria", "Iris", "Peony",
        "Bush Clover", "Pampas Grass", "Chrysanthemum", "Maple", "Willow", "Paulownia"
    ]

    private static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
}

/// 札の種類。
public enum CardType: Int, CaseIterable, Sendable, Codable, Hashable, Comparable {
    case kasu, tane, tanzaku, hikari

    /// 札種の名前（英語。日本語訳は 光・短・タネ・カス）。
    public var name: String {
        switch self {
        case .hikari: "Brights"
        case .tanzaku: "Ribbons"
        case .tane: "Animals"
        case .kasu: "Chaff"
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 花札 1 枚。`id` (0–47) はセーブデータ互換のため go-koikoi と同一の並び。
public struct Card: Identifiable, Sendable, Codable, Hashable {
    public let id: Int
    public let month: Month
    public let type: CardType
    public let name: String

    /// `[花:種]` 形式の短い表示（デバッグ用。例: `[Pine:Brights]`）。
    public var display: String {
        "[\(month.flowerName):\(type.name)]"
    }
}

public extension Card {
    /// 花札 48 枚の定義。並び・ID は go-koikoi の `AllCards` と同一。
    static let all: [Card] = [
        // 1月 松
        Card(id: 0, month: .january, type: .hikari, name: "Pine and Crane"),
        Card(id: 1, month: .january, type: .tanzaku, name: "Pine with Red Ribbon"),
        Card(id: 2, month: .january, type: .kasu, name: "Pine Chaff 1"),
        Card(id: 3, month: .january, type: .kasu, name: "Pine Chaff 2"),
        // 2月 梅
        Card(id: 4, month: .february, type: .tane, name: "Plum and Bush Warbler"),
        Card(id: 5, month: .february, type: .tanzaku, name: "Plum with Red Ribbon"),
        Card(id: 6, month: .february, type: .kasu, name: "Plum Chaff 1"),
        Card(id: 7, month: .february, type: .kasu, name: "Plum Chaff 2"),
        // 3月 桜
        Card(id: 8, month: .march, type: .hikari, name: "Cherry Blossom Curtain"),
        Card(id: 9, month: .march, type: .tanzaku, name: "Cherry Blossom with Red Ribbon"),
        Card(id: 10, month: .march, type: .kasu, name: "Cherry Blossom Chaff 1"),
        Card(id: 11, month: .march, type: .kasu, name: "Cherry Blossom Chaff 2"),
        // 4月 藤
        Card(id: 12, month: .april, type: .tane, name: "Wisteria and Cuckoo"),
        Card(id: 13, month: .april, type: .tanzaku, name: "Wisteria with Ribbon"),
        Card(id: 14, month: .april, type: .kasu, name: "Wisteria Chaff 1"),
        Card(id: 15, month: .april, type: .kasu, name: "Wisteria Chaff 2"),
        // 5月 菖蒲
        Card(id: 16, month: .may, type: .tane, name: "Iris and Eight-Plank Bridge"),
        Card(id: 17, month: .may, type: .tanzaku, name: "Iris with Ribbon"),
        Card(id: 18, month: .may, type: .kasu, name: "Iris Chaff 1"),
        Card(id: 19, month: .may, type: .kasu, name: "Iris Chaff 2"),
        // 6月 牡丹
        Card(id: 20, month: .june, type: .tane, name: "Peony and Butterflies"),
        Card(id: 21, month: .june, type: .tanzaku, name: "Peony with Blue Ribbon"),
        Card(id: 22, month: .june, type: .kasu, name: "Peony Chaff 1"),
        Card(id: 23, month: .june, type: .kasu, name: "Peony Chaff 2"),
        // 7月 萩
        Card(id: 24, month: .july, type: .tane, name: "Bush Clover and Boar"),
        Card(id: 25, month: .july, type: .tanzaku, name: "Bush Clover with Ribbon"),
        Card(id: 26, month: .july, type: .kasu, name: "Bush Clover Chaff 1"),
        Card(id: 27, month: .july, type: .kasu, name: "Bush Clover Chaff 2"),
        // 8月 芒
        Card(id: 28, month: .august, type: .hikari, name: "Pampas Grass and Moon"),
        Card(id: 29, month: .august, type: .tane, name: "Pampas Grass and Geese"),
        Card(id: 30, month: .august, type: .kasu, name: "Pampas Grass Chaff 1"),
        Card(id: 31, month: .august, type: .kasu, name: "Pampas Grass Chaff 2"),
        // 9月 菊
        Card(id: 32, month: .september, type: .tane, name: "Chrysanthemum and Sake Cup"),
        Card(id: 33, month: .september, type: .tanzaku, name: "Chrysanthemum with Blue Ribbon"),
        Card(id: 34, month: .september, type: .kasu, name: "Chrysanthemum Chaff 1"),
        Card(id: 35, month: .september, type: .kasu, name: "Chrysanthemum Chaff 2"),
        // 10月 紅葉
        Card(id: 36, month: .october, type: .tane, name: "Maple and Deer"),
        Card(id: 37, month: .october, type: .tanzaku, name: "Maple with Blue Ribbon"),
        Card(id: 38, month: .october, type: .kasu, name: "Maple Chaff 1"),
        Card(id: 39, month: .october, type: .kasu, name: "Maple Chaff 2"),
        // 11月 柳
        Card(id: 40, month: .november, type: .hikari, name: "Willow and Ono no Michikaze"),
        Card(id: 41, month: .november, type: .tane, name: "Willow and Swallow"),
        Card(id: 42, month: .november, type: .tanzaku, name: "Willow with Ribbon"),
        Card(id: 43, month: .november, type: .kasu, name: "Willow Chaff"),
        // 12月 桐
        Card(id: 44, month: .december, type: .hikari, name: "Paulownia and Phoenix"),
        Card(id: 45, month: .december, type: .kasu, name: "Paulownia Chaff 1"),
        Card(id: 46, month: .december, type: .kasu, name: "Paulownia Chaff 2"),
        Card(id: 47, month: .december, type: .kasu, name: "Paulownia Chaff 3")
    ]

    /// ID から札を引く（0–47 の範囲外は nil）。
    static func card(id: Int) -> Card? {
        guard Card.all.indices.contains(id) else { return nil }
        return Card.all[id]
    }
}
