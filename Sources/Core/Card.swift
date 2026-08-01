import Foundation

/// 月（花の種類）。ngs/go-koikoi の `Month` に対応する。
public enum Month: Int, CaseIterable, Sendable, Codable, Hashable {
    case january, february, march, april, may, june
    case july, august, september, october, november, december

    /// 花の名前（松・梅・桜…）
    public var flowerName: String {
        Self.flowerNames[rawValue]
    }

    /// 旧暦の月名（睦月・如月…）
    public var oldName: String {
        Self.oldNames[rawValue]
    }

    private static let flowerNames = [
        "松", "梅", "桜", "藤", "菖蒲", "牡丹",
        "萩", "芒", "菊", "紅葉", "柳", "桐"
    ]

    private static let oldNames = [
        "睦月", "如月", "弥生", "卯月", "皐月", "水無月",
        "文月", "葉月", "長月", "神無月", "霜月", "師走"
    ]
}

/// 札の種類。
public enum CardType: Int, CaseIterable, Sendable, Codable, Hashable, Comparable {
    case kasu, tane, tanzaku, hikari

    /// 1 文字シンボル（光・短・種・カ）。
    public var symbol: String {
        switch self {
        case .hikari: "光"
        case .tanzaku: "短"
        case .tane: "種"
        case .kasu: "カ"
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

    /// `[月:種]` 形式の短い表示（例: `[松:光]`）。
    public var display: String {
        "[\(month.flowerName):\(type.symbol)]"
    }
}

public extension Card {
    /// 花札 48 枚の定義。並び・ID は go-koikoi の `AllCards` と同一。
    static let all: [Card] = [
        // 1月 松
        Card(id: 0, month: .january, type: .hikari, name: "松に鶴"),
        Card(id: 1, month: .january, type: .tanzaku, name: "松に赤短"),
        Card(id: 2, month: .january, type: .kasu, name: "松のカス１"),
        Card(id: 3, month: .january, type: .kasu, name: "松のカス２"),
        // 2月 梅
        Card(id: 4, month: .february, type: .tane, name: "梅に鶯"),
        Card(id: 5, month: .february, type: .tanzaku, name: "梅に赤短"),
        Card(id: 6, month: .february, type: .kasu, name: "梅のカス１"),
        Card(id: 7, month: .february, type: .kasu, name: "梅のカス２"),
        // 3月 桜
        Card(id: 8, month: .march, type: .hikari, name: "桜に幕"),
        Card(id: 9, month: .march, type: .tanzaku, name: "桜に赤短"),
        Card(id: 10, month: .march, type: .kasu, name: "桜のカス１"),
        Card(id: 11, month: .march, type: .kasu, name: "桜のカス２"),
        // 4月 藤
        Card(id: 12, month: .april, type: .tane, name: "藤に不如帰"),
        Card(id: 13, month: .april, type: .tanzaku, name: "藤に短冊"),
        Card(id: 14, month: .april, type: .kasu, name: "藤のカス１"),
        Card(id: 15, month: .april, type: .kasu, name: "藤のカス２"),
        // 5月 菖蒲
        Card(id: 16, month: .may, type: .tane, name: "菖蒲に八橋"),
        Card(id: 17, month: .may, type: .tanzaku, name: "菖蒲に短冊"),
        Card(id: 18, month: .may, type: .kasu, name: "菖蒲のカス１"),
        Card(id: 19, month: .may, type: .kasu, name: "菖蒲のカス２"),
        // 6月 牡丹
        Card(id: 20, month: .june, type: .tane, name: "牡丹に蝶"),
        Card(id: 21, month: .june, type: .tanzaku, name: "牡丹に短冊"),
        Card(id: 22, month: .june, type: .kasu, name: "牡丹のカス１"),
        Card(id: 23, month: .june, type: .kasu, name: "牡丹のカス２"),
        // 7月 萩
        Card(id: 24, month: .july, type: .tane, name: "萩に猪"),
        Card(id: 25, month: .july, type: .tanzaku, name: "萩に短冊"),
        Card(id: 26, month: .july, type: .kasu, name: "萩のカス１"),
        Card(id: 27, month: .july, type: .kasu, name: "萩のカス２"),
        // 8月 芒
        Card(id: 28, month: .august, type: .hikari, name: "芒に月"),
        Card(id: 29, month: .august, type: .tane, name: "芒に雁"),
        Card(id: 30, month: .august, type: .kasu, name: "芒のカス１"),
        Card(id: 31, month: .august, type: .kasu, name: "芒のカス２"),
        // 9月 菊
        Card(id: 32, month: .september, type: .tane, name: "菊に盃"),
        Card(id: 33, month: .september, type: .tanzaku, name: "菊に短冊"),
        Card(id: 34, month: .september, type: .kasu, name: "菊のカス１"),
        Card(id: 35, month: .september, type: .kasu, name: "菊のカス２"),
        // 10月 紅葉
        Card(id: 36, month: .october, type: .tane, name: "紅葉に鹿"),
        Card(id: 37, month: .october, type: .tanzaku, name: "紅葉に短冊"),
        Card(id: 38, month: .october, type: .kasu, name: "紅葉のカス１"),
        Card(id: 39, month: .october, type: .kasu, name: "紅葉のカス２"),
        // 11月 柳
        Card(id: 40, month: .november, type: .hikari, name: "柳に小野道風"),
        Card(id: 41, month: .november, type: .tane, name: "柳に燕"),
        Card(id: 42, month: .november, type: .tanzaku, name: "柳に短冊"),
        Card(id: 43, month: .november, type: .kasu, name: "柳のカス"),
        // 12月 桐
        Card(id: 44, month: .december, type: .hikari, name: "桐に鳳凰"),
        Card(id: 45, month: .december, type: .kasu, name: "桐のカス１"),
        Card(id: 46, month: .december, type: .kasu, name: "桐のカス２"),
        Card(id: 47, month: .december, type: .kasu, name: "桐のカス３")
    ]

    /// ID から札を引く（0–47 の範囲外は nil）。
    static func card(id: Int) -> Card? {
        guard Card.all.indices.contains(id) else { return nil }
        return Card.all[id]
    }
}
