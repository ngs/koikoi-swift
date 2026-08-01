import Foundation

/// 対戦相手の難易度。go-koikoi の `Difficulty` に対応する
/// （`.search` は koikoi-swift 追加の ISMCTS 探索エンジン用）。
public enum Difficulty: String, Sendable, Codable, CaseIterable {
    case easy
    case normal
    case hard
    /// ISMCTS 探索（KoikoiAI モジュールが実装）。
    case search

    public var label: String {
        switch self {
        case .easy: "かんたん"
        case .normal: "ふつう"
        case .hard: "つよい"
        case .search: "たつじん"
        }
    }
}

/// ヒューリスティック打ち手（go-koikoi の cpu.go の移植）。
/// かんたん/ふつう/つよい難易度の実体で、ISMCTS のロールアウト方策としても使う。
public enum HeuristicOpponent {
    /// 出す手札（と 2 枚マッチ時の場札の選択）を選ぶ。
    public static func chooseHandCard(
        game: Game, seat: Seat, difficulty: Difficulty, rng: inout GameRandom
    ) -> (handCard: Card, fieldChoice: Card?) {
        let hand = game.hand(for: seat)
        precondition(!hand.isEmpty, "hand must not be empty")

        // Easy: 一定確率でランダムに選ぶ
        if difficulty == .easy, Int.random(in: 0..<3, using: &rng) == 0 {
            let card = hand[Int.random(in: 0..<hand.count, using: &rng)]
            let matches = game.matchingFieldCards(for: card)
            if matches.count == 2 {
                return (card, matches[Int.random(in: 0..<2, using: &rng)])
            }
            return (card, nil)
        }

        var bestScore = -1
        var bestCard = hand[0]
        var bestFieldChoice: Card?

        for card in hand {
            let matches = game.matchingFieldCards(for: card)
            var score = evaluatePlay(hand: card, matches: matches)

            // Hard: 役に近い札をボーナス評価
            if difficulty == .hard {
                score += evaluateYakuPotential(game: game, seat: seat, matches: matches, hand: card)
            }

            if score > bestScore {
                bestScore = score
                bestCard = card
                bestFieldChoice = matches.count == 2 ? chooseBestMatch(matches) : nil
            }
        }

        // マッチがない場合、一番価値の低い札を捨てる
        if game.matchingFieldCards(for: bestCard).isEmpty {
            let lowest = hand.min { cardValue($0) < cardValue($1) } ?? bestCard
            return (lowest, nil)
        }

        return (bestCard, bestFieldChoice)
    }

    /// 山札から引いた札に対して場札を選ぶ。
    public static func chooseFieldCard(matches: [Card]) -> Card? {
        matches.count == 2 ? chooseBestMatch(matches) : nil
    }

    /// こいこいするかどうか判断する。
    public static func decideKoikoi(
        game: Game, seat: Seat, yakus: [Yaku], difficulty: Difficulty
    ) -> Bool {
        let points = YakuChecker.totalPoints(yakus)
        let handCount = game.hand(for: seat).count

        switch difficulty {
        case .easy:
            // かんたん: 常に勝負（こいこいしない）
            return false
        case .hard, .search:
            // つよい: 手札に余裕があれば積極的にこいこい
            if handCount <= 1 { return false }
            if points >= 10 { return false }
            return true
        case .normal:
            // ふつう: 従来ロジック
            if handCount <= 2 { return false }
            if points >= 7 { return false }
            return true
        }
    }

    // MARK: - 評価関数

    /// Hard モード用: 役への近さを評価する。
    static func evaluateYakuPotential(game: Game, seat: Seat, matches: [Card], hand: Card) -> Int {
        guard !matches.isEmpty else { return 0 }
        var bonus = 0
        let capturedIDs = Set(game.captured(for: seat).map(\.id))

        // 光札を取れるなら大きなボーナス
        bonus += matches.count(where: { $0.type == .hikari }) * 15
        if hand.type == .hikari {
            bonus += 10
        }

        // 猪鹿蝶に近い札
        for match in matches where CardID.inoshikacho.contains(match.id) && !capturedIDs.contains(match.id) {
            bonus += 8
        }

        // 赤短・青短に近い札
        let colorTanzaku = CardID.akatan + CardID.aotan
        for match in matches where colorTanzaku.contains(match.id) && !capturedIDs.contains(match.id) {
            bonus += 6
        }

        return bonus
    }

    static func evaluatePlay(hand: Card, matches: [Card]) -> Int {
        guard !matches.isEmpty else { return 0 }
        return cardValue(hand) + matches.reduce(0) { $0 + cardValue($1) }
    }

    static func cardValue(_ card: Card) -> Int {
        switch card.type {
        case .hikari: 20
        case .tane: 10
        case .tanzaku: 5
        case .kasu: 1
        }
    }

    static func chooseBestMatch(_ matches: [Card]) -> Card {
        matches.max { cardValue($0) < cardValue($1) } ?? matches[0]
    }
}
