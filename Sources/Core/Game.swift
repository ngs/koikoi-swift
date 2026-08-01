import Foundation

/// 対局の席。go-koikoi の `isPlayer bool` に対応する。
public enum Seat: Sendable, Codable, Hashable, CaseIterable {
    case player
    case opponent

    public var other: Seat {
        self == .player ? .opponent : .player
    }
}

/// 決定的に再現可能な乱数生成器（SplitMix64）。
/// ゲーム状態ごと値コピーされるため、MCTS のシミュレーションやテストで
/// 同一シードから同一進行を再現できる。
public struct GameRandom: RandomNumberGenerator, Sendable, Codable, Hashable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    /// 非決定的なシードで初期化（通常対局用）。
    public init() {
        self.init(seed: UInt64.random(in: .min ... .max))
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// ゲーム状態。go-koikoi の game.go の移植（値型・RNG 注入可能）。
public struct Game: Sendable, Codable, Hashable {
    public var deck: [Card] = []
    public var field: [Card] = []
    public internal(set) var hands: [Seat: [Card]] = [.player: [], .opponent: []]
    public internal(set) var captured: [Seat: [Card]] = [.player: [], .opponent: []]
    public var scores: [Seat: Int] = [.player: 0, .opponent: 0]
    public var round: Int
    public var maxRounds: Int
    public var currentTurn: Seat = .player
    /// 前回チェック時の役（こいこい判定用）。
    public var previousYaku: [Seat: [Yaku]] = [.player: [], .opponent: []]
    /// こいこい宣言フラグ（ラウンド内）。
    public var koikoiDeclared: [Seat: Bool] = [.player: false, .opponent: false]
    /// 次ラウンドの親。
    public var nextParent: Seat = .player
    /// 親決めで引いた札（表示用）。
    public var parentDrawnCards: [Seat: Card] = [:]

    var rng: GameRandom

    /// 新しいゲームを開始（親決めまで行う）。
    public init(rounds: Int, rng: GameRandom = GameRandom()) {
        round = 1
        maxRounds = rounds
        self.rng = rng
        determineParent()
    }

    // MARK: - Accessors

    public func hand(for seat: Seat) -> [Card] {
        hands[seat] ?? []
    }

    /// 手札を差し替える（AI 探索の決定化・テスト用。通常進行では使わない）。
    public mutating func setHand(_ cards: [Card], for seat: Seat) {
        hands[seat] = cards
    }

    public func captured(for seat: Seat) -> [Card] {
        captured[seat] ?? []
    }

    public func score(for seat: Seat) -> Int {
        scores[seat] ?? 0
    }

    /// 手札がなくなったか。
    public var isRoundOver: Bool {
        hand(for: .player).isEmpty && hand(for: .opponent).isEmpty
    }

    // MARK: - Setup

    /// 親決め: 山札から 1 枚ずつ引き、月が若い方が親。
    mutating func determineParent() {
        let deck = Card.all.shuffled(using: &rng)

        var index = 0
        while true {
            let playerCard = deck[index]
            let opponentCard = deck[index + 1]
            index += 2

            if playerCard.month != opponentCard.month {
                nextParent = playerCard.month.rawValue < opponentCard.month.rawValue
                    ? .player : .opponent
                parentDrawnCards = [.player: playerCard, .opponent: opponentCard]
                return
            }
            // 同じ月の場合は引き直し
            if index + 2 > deck.count {
                index = 0
            }
        }
    }

    /// ラウンド開始: シャッフルして配る。
    public mutating func startRound() {
        deck = Card.all.shuffled(using: &rng)

        hands = [.player: [], .opponent: []]
        field = []
        captured = [.player: [], .opponent: []]
        previousYaku = [.player: [], .opponent: []]
        koikoiDeclared = [.player: false, .opponent: false]

        // 配札: 手札 8 枚ずつ、場札 8 枚
        for _ in 0..<8 {
            let playerCard = draw()
            hands[.player]?.append(playerCard)
            let opponentCard = draw()
            hands[.opponent]?.append(opponentCard)
        }
        for _ in 0..<8 {
            let fieldCard = draw()
            field.append(fieldCard)
        }

        // 前ラウンドの勝者が親（先攻）
        currentTurn = nextParent
    }

    private mutating func draw() -> Card {
        deck.removeFirst()
    }

    /// 山札から 1 枚引く。山が尽きていたら nil。
    public mutating func drawFromDeck() -> Card? {
        deck.isEmpty ? nil : draw()
    }

    // MARK: - Matching

    /// 場に出ている同月の札を返す。
    public func matchingFieldCards(for card: Card) -> [Card] {
        field.filter { $0.month == card.month }
    }

    /// 手札から場に出してマッチング処理を行う。
    /// - Parameter fieldChoice: 場札の中から選んだ札（マッチが複数ある場合）。
    /// - Returns: 獲得した札。
    @discardableResult
    public mutating func playCard(_ handCard: Card, fieldChoice: Card?, by seat: Seat) -> [Card] {
        hands[seat] = hand(for: seat).removingCard(handCard)
        return resolveMatch(for: handCard, fieldChoice: fieldChoice, by: seat)
    }

    /// 山札から引いた札を場に合わせる。
    /// - Returns: 獲得した札。
    @discardableResult
    public mutating func playDrawnCard(_ drawnCard: Card, fieldChoice: Card?, by seat: Seat) -> [Card] {
        resolveMatch(for: drawnCard, fieldChoice: fieldChoice, by: seat)
    }

    private mutating func resolveMatch(for card: Card, fieldChoice: Card?, by seat: Seat) -> [Card] {
        let matches = matchingFieldCards(for: card)

        var newlyCaptured: [Card] = []
        switch matches.count {
        case 0:
            // マッチなし → 場に置く
            field.append(card)
        case 1:
            newlyCaptured = [card, matches[0]]
            field = field.removingCard(matches[0])
        case 2:
            // 2 枚マッチ → 選択した 1 枚（未指定なら最初の 1 枚）を獲得
            let choice = fieldChoice ?? matches[0]
            newlyCaptured = [card, choice]
            field = field.removingCard(choice)
        default:
            // 3 枚マッチ → 全て獲得
            newlyCaptured = [card] + matches
            for match in matches {
                field = field.removingCard(match)
            }
        }

        captured[seat] = captured(for: seat) + newlyCaptured
        return newlyCaptured
    }

    // MARK: - Yaku

    /// 新しく成立した役があるかチェック。
    public func checkNewYaku(for seat: Seat) -> [Yaku] {
        let current = YakuChecker.checkYaku(captured: captured(for: seat))
        let previous = previousYaku[seat] ?? []
        return current.filter { !previous.contains($0) }
    }

    /// 前回の役を更新（こいこい後）。
    public mutating func updatePreviousYaku(for seat: Seat) {
        previousYaku[seat] = YakuChecker.checkYaku(captured: captured(for: seat))
    }

    /// 最終得点を計算する（7 文以上 2 倍、相手こいこい時さらに 2 倍）。
    public func calcFinalScore(for seat: Seat) -> Int {
        let yakus = YakuChecker.checkYaku(captured: captured(for: seat))
        var total = YakuChecker.totalPoints(yakus)

        // 7 文以上で 2 倍
        if total >= 7 {
            total *= 2
        }
        // 相手がこいこいしていた場合、さらに 2 倍
        if koikoiDeclared[seat.other] == true {
            total *= 2
        }
        return total
    }
}

extension [Card] {
    /// ID の一致する最初の札を取り除いた配列を返す（見つからなければそのまま）。
    func removingCard(_ target: Card) -> [Card] {
        guard let index = firstIndex(where: { $0.id == target.id }) else { return self }
        var copy = self
        copy.remove(at: index)
        return copy
    }
}
