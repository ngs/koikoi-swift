import Foundation

/// 役の種類。rawValue は保存・比較用の安定した英語識別子で、
/// 表示は `displayName`（英語）を UI 層でローカライズして使う。
/// go-koikoi の役名は各 case のコメントに添える。
public enum YakuKind: String, Sendable, Codable, CaseIterable, Hashable {
    case fiveBrights  // 五光
    case fourBrights  // 四光
    case rainyFourBrights  // 雨四光
    case threeBrights  // 三光
    case boarDeerButterfly  // 猪鹿蝶
    case cherryBlossomViewing  // 花見で一杯
    case moonViewing  // 月見で一杯
    case redPoetryRibbons  // 赤短
    case blueRibbons  // 青短
    case redAndBlueRibbons  // 赤短・青短の重複
    case animals  // タネ
    case ribbons  // タン
    case chaff  // カス

    /// 英語の表示名（String Catalog のキーでもある）。
    public var displayName: String {
        switch self {
        case .fiveBrights: "Five Brights"
        case .fourBrights: "Four Brights"
        case .rainyFourBrights: "Rainy Four Brights"
        case .threeBrights: "Three Brights"
        case .boarDeerButterfly: "Boar, Deer, Butterfly"
        case .cherryBlossomViewing: "Cherry Blossom Viewing"
        case .moonViewing: "Moon Viewing"
        case .redPoetryRibbons: "Red Poetry Ribbons"
        case .blueRibbons: "Blue Ribbons"
        case .redAndBlueRibbons: "Red and Blue Ribbons"
        case .animals: "Animals"
        case .ribbons: "Ribbons"
        case .chaff: "Chaff"
        }
    }
}

/// 成立した役。
public struct Yaku: Sendable, Codable, Hashable {
    public let kind: YakuKind
    public let points: Int

    public init(_ kind: YakuKind, _ points: Int) {
        self.kind = kind
        self.points = points
    }
}

/// リーチ中の役（あと 1 枚で成立）。
public struct YakuReach: Sendable, Hashable {
    public let kind: YakuKind
    /// 不足している札。nil は「同種札あと 1 枚」（タネ・タン・カスなど特定札を問わない場合）。
    public let missing: [Card]?

    public init(_ kind: YakuKind, _ missing: [Card]?) {
        self.kind = kind
        self.missing = missing
    }
}

/// 役判定（任天堂ルール準拠）。go-koikoi の yaku.go の移植。
public enum YakuChecker {
    /// 獲得札から成立している役を判定する。
    public static func checkYaku(captured: [Card]) -> [Yaku] {
        var yakus: [Yaku] = []

        let hikari = captured.filter { $0.type == .hikari }
        let tane = captured.filter { $0.type == .tane }
        let tanzaku = captured.filter { $0.type == .tanzaku }
        let kasu = captured.filter { $0.type == .kasu }

        let hikariIDs = Set(hikari.map(\.id))
        // 柳に小野道風 (40) 以外の光札数
        let hikariNoYanagi = hikariIDs.subtracting([CardID.yanagiHikari]).count

        // 光系（排他: 五光 > 四光 > 雨四光 > 三光）
        let hasGokou = hikariIDs.isSuperset(of: CardID.allHikari)
        let hasShikou = !hasGokou && hikariIDs.isSuperset(of: CardID.noYanagiHikari)
        let hasAmeShikou = !hasGokou && !hasShikou
            && hikariIDs.contains(CardID.yanagiHikari) && hikari.count >= 4
        let hasSankou = !hasGokou && !hasShikou && !hasAmeShikou && hikariNoYanagi >= 3

        if hasGokou {
            yakus.append(Yaku(.fiveBrights, 10))
        } else if hasShikou {
            yakus.append(Yaku(.fourBrights, 8))
        } else if hasAmeShikou {
            yakus.append(Yaku(.rainyFourBrights, 7))
        } else if hasSankou {
            yakus.append(Yaku(.threeBrights, 5))
        }

        // 猪鹿蝶: 5文 + 種札が増えるごとに +1 文
        let taneIDs = Set(tane.map(\.id))
        let hasInoshikacho = taneIDs.isSuperset(of: CardID.inoshikacho)
        if hasInoshikacho {
            yakus.append(Yaku(.boarDeerButterfly, 5 + (tane.count - 3)))
        }

        // 花見で一杯 / 月見で一杯
        let allIDs = Set(captured.map(\.id))
        if allIDs.isSuperset(of: CardID.hanami) {
            yakus.append(Yaku(.cherryBlossomViewing, 5))
        }
        if allIDs.isSuperset(of: CardID.tsukimi) {
            yakus.append(Yaku(.moonViewing, 5))
        }

        // 短冊系（排他: 赤短・青短の重複 > 赤短/青短 > タン）
        let tanzakuIDs = Set(tanzaku.map(\.id))
        let hasAkatan = tanzakuIDs.isSuperset(of: CardID.akatan)
        let hasAotan = tanzakuIDs.isSuperset(of: CardID.aotan)

        if hasAkatan, hasAotan {
            // 赤短・青短の重複: 10 文 + 短冊が増えるごとに +1 文
            yakus.append(Yaku(.redAndBlueRibbons, 10 + max(tanzaku.count - 6, 0)))
        } else if hasAkatan {
            yakus.append(Yaku(.redPoetryRibbons, 5 + max(tanzaku.count - 3, 0)))
        } else if hasAotan {
            yakus.append(Yaku(.blueRibbons, 5 + max(tanzaku.count - 3, 0)))
        }

        // タネ: 種札 5 枚以上で 1 文 + 1 枚ごとに +1 文（猪鹿蝶ができたら無効）
        if !hasInoshikacho, tane.count >= 5 {
            yakus.append(Yaku(.animals, 1 + (tane.count - 5)))
        }

        // タン: 短冊札 5 枚以上で 1 文 + 1 枚ごとに +1 文（赤短か青短ができたら無効）
        if !hasAkatan, !hasAotan, tanzaku.count >= 5 {
            yakus.append(Yaku(.ribbons, 1 + (tanzaku.count - 5)))
        }

        // カス: カス札 10 枚以上で 1 文 + 1 枚ごとに +1 文
        if kasu.count >= 10 {
            yakus.append(Yaku(.chaff, 1 + (kasu.count - 10)))
        }

        return yakus
    }

    /// リーチ判定の共有コンテキスト。
    private struct ReachContext {
        let hikari: [Card]
        let tane: [Card]
        let tanzaku: [Card]
        let kasu: [Card]
        let hikariIDs: Set<Int>
        let taneIDs: Set<Int>
        let tanzakuIDs: Set<Int>
        let allIDs: Set<Int>
        let opponentIDs: Set<Int>
        let existing: Set<YakuKind>

        init(captured: [Card], opponentCaptured: [Card]) {
            hikari = captured.filter { $0.type == .hikari }
            tane = captured.filter { $0.type == .tane }
            tanzaku = captured.filter { $0.type == .tanzaku }
            kasu = captured.filter { $0.type == .kasu }
            hikariIDs = Set(hikari.map(\.id))
            taneIDs = Set(tane.map(\.id))
            tanzakuIDs = Set(tanzaku.map(\.id))
            allIDs = Set(captured.map(\.id))
            opponentIDs = Set(opponentCaptured.map(\.id))
            existing = Set(YakuChecker.checkYaku(captured: captured).map(\.kind))
        }

        func hasYaku(_ kind: YakuKind) -> Bool {
            existing.contains(kind)
        }

        /// 不足札を返す（相手が持っている札は除外）。ID 昇順。
        func missingCards(required: [Int], have: Set<Int>) -> [Card] {
            required
                .filter { !have.contains($0) && !opponentIDs.contains($0) }
                .compactMap(Card.card(id:))
        }
    }

    /// 獲得札からリーチ中の役を判定する。
    /// - Parameter opponentCaptured: 相手の獲得札（不足札が相手に取られていたらリーチから除外）。
    public static func checkReach(captured: [Card], opponentCaptured: [Card]) -> [YakuReach] {
        let context = ReachContext(captured: captured, opponentCaptured: opponentCaptured)
        return hikariReaches(context)
            + setReaches(context)
            + tanzakuReaches(context)
            + countReaches(context)
    }

    /// 光系（五光・四光・雨四光・三光）のリーチ。
    private static func hikariReaches(_ context: ReachContext) -> [YakuReach] {
        var reaches: [YakuReach] = []
        let hikariNoYanagi = context.hikariIDs.subtracting([CardID.yanagiHikari]).count
        let hasYanagi = context.hikariIDs.contains(CardID.yanagiHikari)

        // 五光リーチ（光札 4 枚）
        if !context.hasYaku(.fiveBrights), context.hikari.count == 4 {
            let missing = context.missingCards(required: CardID.allHikari, have: context.hikariIDs)
            if missing.count == 1 {
                reaches.append(YakuReach(.fiveBrights, missing))
            }
        }

        // 四光リーチ（柳以外の光 3 枚・柳なし）
        if !context.hasYaku(.fourBrights), !context.hasYaku(.fiveBrights), hikariNoYanagi == 3, !hasYanagi {
            let missing = context.missingCards(
                required: CardID.noYanagiHikari, have: context.hikariIDs)
            if missing.count == 1 {
                reaches.append(YakuReach(.fourBrights, missing))
            }
        }

        // 雨四光リーチ
        if !context.hasYaku(.rainyFourBrights), !context.hasYaku(.fourBrights), !context.hasYaku(.fiveBrights) {
            if hasYanagi, hikariNoYanagi == 2 {
                // 柳あり + 柳以外 2 枚 → 柳以外の光あと 1 枚
                let missing = context.missingCards(
                    required: CardID.noYanagiHikari, have: context.hikariIDs)
                reaches.append(YakuReach(.rainyFourBrights, missing))
            } else if !hasYanagi, hikariNoYanagi == 3 {
                // 三光成立中 → 柳を取れば雨四光
                reaches.append(YakuReach(.rainyFourBrights, [Card.all[CardID.yanagiHikari]]))
            }
        }

        // 三光リーチ（柳以外の光 2 枚・柳なし）
        if !context.hasYaku(.threeBrights), !context.hasYaku(.rainyFourBrights), !context.hasYaku(.fourBrights),
            !context.hasYaku(.fiveBrights), hikariNoYanagi == 2, !hasYanagi {
            let missing = context.missingCards(
                required: CardID.noYanagiHikari, have: context.hikariIDs)
            reaches.append(YakuReach(.threeBrights, missing))
        }

        return reaches
    }

    /// 特定札の組み合わせ役（猪鹿蝶・花見・月見）のリーチ。
    private static func setReaches(_ context: ReachContext) -> [YakuReach] {
        var reaches: [YakuReach] = []

        // 猪鹿蝶（3 枚中 2 枚保持・残り 1 枚が相手に取られていない）
        if !context.hasYaku(.boarDeerButterfly),
            CardID.inoshikacho.filter(context.taneIDs.contains).count == 2 {
            let missing = context.missingCards(
                required: CardID.inoshikacho, have: context.taneIDs)
            if missing.count == 1 {
                reaches.append(YakuReach(.boarDeerButterfly, missing))
            }
        }

        // 花見で一杯 / 月見で一杯（2 枚中 1 枚保持・残りが相手に取られていない）
        for (kind, required) in [(YakuKind.cherryBlossomViewing, CardID.hanami), (.moonViewing, CardID.tsukimi)] {
            if !context.hasYaku(kind), required.filter(context.allIDs.contains).count == 1 {
                let missing = context.missingCards(required: required, have: context.allIDs)
                if missing.count == 1 {
                    reaches.append(YakuReach(kind, missing))
                }
            }
        }

        return reaches
    }

    /// 短冊系（赤短・青短・重複）のリーチ。
    private static func tanzakuReaches(_ context: ReachContext) -> [YakuReach] {
        guard !context.hasYaku(.redAndBlueRibbons) else { return [] }

        let akatanDone = context.hasYaku(.redPoetryRibbons)
        let aotanDone = context.hasYaku(.blueRibbons)
        let akatanMissing = context.missingCards(required: CardID.akatan, have: context.tanzakuIDs)
        let aotanMissing = context.missingCards(required: CardID.aotan, have: context.tanzakuIDs)
        // リーチ条件: 3 枚中 2 枚を自分が持っていて、もう 1 枚が相手に取られていない
        let akatanReach = akatanMissing.count == 1
            && CardID.akatan.filter(context.tanzakuIDs.contains).count == 2
        let aotanReach = aotanMissing.count == 1
            && CardID.aotan.filter(context.tanzakuIDs.contains).count == 2

        if akatanDone, aotanReach {
            return [YakuReach(.redAndBlueRibbons, aotanMissing)]
        }
        if aotanDone, akatanReach {
            return [YakuReach(.redAndBlueRibbons, akatanMissing)]
        }

        var reaches: [YakuReach] = []
        if !akatanDone, akatanReach {
            reaches.append(YakuReach(.redPoetryRibbons, akatanMissing))
        }
        if !aotanDone, aotanReach {
            reaches.append(YakuReach(.blueRibbons, aotanMissing))
        }
        return reaches
    }

    /// 枚数役（タネ・タン・カス）のリーチ。
    private static func countReaches(_ context: ReachContext) -> [YakuReach] {
        var reaches: [YakuReach] = []
        let akatanDone = context.hasYaku(.redPoetryRibbons) || context.hasYaku(.redAndBlueRibbons)
        let aotanDone = context.hasYaku(.blueRibbons) || context.hasYaku(.redAndBlueRibbons)

        // タネ（5 枚・猪鹿蝶未成立時のみ）
        if !context.hasYaku(.animals), !context.hasYaku(.boarDeerButterfly), context.tane.count == 4 {
            reaches.append(YakuReach(.animals, nil))
        }
        // タン（5 枚・赤短/青短未成立時のみ）
        if !context.hasYaku(.ribbons), !akatanDone, !aotanDone, context.tanzaku.count == 4 {
            reaches.append(YakuReach(.ribbons, nil))
        }
        // カス（10 枚）
        if !context.hasYaku(.chaff), context.kasu.count == 9 {
            reaches.append(YakuReach(.chaff, nil))
        }
        return reaches
    }

    /// 役の合計点。
    public static func totalPoints(_ yakus: [Yaku]) -> Int {
        yakus.reduce(0) { $0 + $1.points }
    }
}

/// 役判定で使う札 ID 定数。
enum CardID {
    /// 柳に小野道風
    static let yanagiHikari = 40
    /// 光札 5 枚（松に鶴・桜に幕・芒に月・柳に小野道風・桐に鳳凰）
    static let allHikari = [0, 8, 28, 40, 44]
    /// 柳を除く光札 4 枚
    static let noYanagiHikari = [0, 8, 28, 44]
    /// 萩に猪・紅葉に鹿・牡丹に蝶
    static let inoshikacho = [20, 24, 36]
    /// 桜に幕・菊に盃
    static let hanami = [8, 32]
    /// 芒に月・菊に盃
    static let tsukimi = [28, 32]
    /// 松・梅・桜の赤短
    static let akatan = [1, 5, 9]
    /// 牡丹・菊・紅葉の青短
    static let aotan = [21, 33, 37]
}
