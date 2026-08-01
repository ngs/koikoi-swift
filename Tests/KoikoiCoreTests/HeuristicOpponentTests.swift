import Testing

@testable import KoikoiCore

@Suite struct HeuristicOpponentTests {
    private func makeGame(hand: [Int], field: [Int], captured: [Int] = []) -> Game {
        var game = Game(rounds: 12, rng: GameRandom(seed: 100))
        game.hands[.opponent] = cards(hand)
        game.field = cards(field)
        game.captured[.opponent] = cards(captured)
        return game
    }

    /// Easy でも常に手札の中から返す（ランダム要素があるため繰り返し）。
    @Test func chooseHandCardEasyReturnsCardInHand() {
        let game = makeGame(hand: [0, 4, 12], field: [2, 6])
        var rng = GameRandom(seed: 7)
        for _ in 0..<20 {
            let (hand, _) = HeuristicOpponent.chooseHandCard(
                game: game, seat: .opponent, difficulty: .easy, rng: &rng)
            #expect(game.hand(for: .opponent).contains(hand))
        }
    }

    /// Normal は価値の高いマッチ（光）を選ぶ。
    @Test func chooseHandCardNormal() {
        let game = makeGame(hand: [0, 2], field: [1])
        var rng = GameRandom(seed: 8)
        let (hand, _) = HeuristicOpponent.chooseHandCard(
            game: game, seat: .opponent, difficulty: .normal, rng: &rng)
        #expect(hand.id == 0)
    }

    /// Hard は光札を取れるマッチにボーナスがつく。
    @Test func chooseHandCardHard() {
        let game = makeGame(hand: [2, 14], field: [0, 12])
        var rng = GameRandom(seed: 9)
        let (hand, _) = HeuristicOpponent.chooseHandCard(
            game: game, seat: .opponent, difficulty: .hard, rng: &rng)
        #expect(hand.id == 2)
    }

    /// マッチがない場合、一番価値の低い札を捨てる。
    @Test func chooseHandCardNoMatch() {
        let game = makeGame(hand: [0, 2], field: [12])
        var rng = GameRandom(seed: 10)
        let (hand, _) = HeuristicOpponent.chooseHandCard(
            game: game, seat: .opponent, difficulty: .normal, rng: &rng)
        #expect(hand.id == 2)
    }

    /// 2 枚マッチでは価値の高い場札を選ぶ（光 > 短冊）。
    @Test func chooseHandCardTwoMatch() {
        let game = makeGame(hand: [2], field: [0, 1])
        var rng = GameRandom(seed: 11)
        let (hand, fieldChoice) = HeuristicOpponent.chooseHandCard(
            game: game, seat: .opponent, difficulty: .normal, rng: &rng)
        #expect(hand.id == 2)
        #expect(fieldChoice?.id == 0)
    }

    @Test func chooseFieldCard() {
        #expect(HeuristicOpponent.chooseFieldCard(matches: cards(1, 0))?.id == 0)
        #expect(HeuristicOpponent.chooseFieldCard(matches: cards(1)) == nil)
        #expect(HeuristicOpponent.chooseFieldCard(matches: cards(1, 2, 3)) == nil)
        #expect(HeuristicOpponent.chooseFieldCard(matches: []) == nil)
    }

    // MARK: - こいこい判断

    @Test func decideKoikoiEasyNeverKoikoi() {
        var game = makeGame(hand: [], field: [])
        game.hands[.opponent] = cards(0, 1, 2, 4, 5)
        let koikoi = HeuristicOpponent.decideKoikoi(
            game: game, seat: .opponent, yakus: [Yaku(.sankou, 5)], difficulty: .easy)
        #expect(!koikoi)
    }

    @Test func decideKoikoiNormal() {
        var game = makeGame(hand: [], field: [])
        let yakus = [Yaku(.sankou, 5)]
        // 手札3枚・5文 → こいこいする
        game.hands[.opponent] = cards(0, 1, 2)
        #expect(
            HeuristicOpponent.decideKoikoi(
                game: game, seat: .opponent, yakus: yakus, difficulty: .normal))
        // 手札2枚 → しない
        game.hands[.opponent] = cards(0, 1)
        #expect(
            !HeuristicOpponent.decideKoikoi(
                game: game, seat: .opponent, yakus: yakus, difficulty: .normal))
        // 手札3枚・7文 → しない
        game.hands[.opponent] = cards(0, 1, 2)
        #expect(
            !HeuristicOpponent.decideKoikoi(
                game: game, seat: .opponent, yakus: [Yaku(.ameShikou, 7)], difficulty: .normal))
    }

    @Test func decideKoikoiHard() {
        var game = makeGame(hand: [], field: [])
        let yakus = [Yaku(.sankou, 5)]
        // 手札3枚・5文 → こいこいする
        game.hands[.opponent] = cards(0, 1, 2)
        #expect(
            HeuristicOpponent.decideKoikoi(
                game: game, seat: .opponent, yakus: yakus, difficulty: .hard))
        // 手札1枚 → しない
        game.hands[.opponent] = cards(0)
        #expect(
            !HeuristicOpponent.decideKoikoi(
                game: game, seat: .opponent, yakus: yakus, difficulty: .hard))
        // 手札3枚・10文 → しない
        game.hands[.opponent] = cards(0, 1, 2)
        #expect(
            !HeuristicOpponent.decideKoikoi(
                game: game, seat: .opponent, yakus: [Yaku(.gokou, 10)], difficulty: .hard))
        // 手札2枚・9文 → こいこいする
        game.hands[.opponent] = cards(0, 1)
        #expect(
            HeuristicOpponent.decideKoikoi(
                game: game, seat: .opponent,
                yakus: [Yaku(.shikou, 8), Yaku(.kasu, 1)], difficulty: .hard))
    }

    // MARK: - 評価関数

    @Test func evaluatePlay() {
        #expect(HeuristicOpponent.evaluatePlay(hand: Card.all[0], matches: []) == 0)
        // 光(20) + 短冊(5)
        #expect(HeuristicOpponent.evaluatePlay(hand: Card.all[0], matches: cards(1)) == 25)
    }

    @Test func cardValue() {
        #expect(HeuristicOpponent.cardValue(Card.all[0]) == 20)  // 光
        #expect(HeuristicOpponent.cardValue(Card.all[4]) == 10)  // 種
        #expect(HeuristicOpponent.cardValue(Card.all[1]) == 5)  // 短冊
        #expect(HeuristicOpponent.cardValue(Card.all[2]) == 1)  // カス
    }

    @Test func chooseBestMatch() {
        #expect(HeuristicOpponent.chooseBestMatch(cards(1, 0)).id == 0)
        #expect(HeuristicOpponent.chooseBestMatch(cards(2, 1)).id == 1)
    }

    @Test func yakuPotentialNoMatches() {
        let game = makeGame(hand: [], field: [])
        #expect(
            HeuristicOpponent.evaluateYakuPotential(
                game: game, seat: .opponent, matches: [], hand: Card.all[0]) == 0)
    }

    /// 光マッチ +15、光を手から出す +10。
    @Test func yakuPotentialHikari() {
        let game = makeGame(hand: [], field: [])
        let bonus = HeuristicOpponent.evaluateYakuPotential(
            game: game, seat: .opponent, matches: cards(0), hand: Card.all[2])
        #expect(bonus == 15)
        let bonusWithHikariHand = HeuristicOpponent.evaluateYakuPotential(
            game: game, seat: .opponent, matches: cards(2), hand: Card.all[0])
        #expect(bonusWithHikariHand == 10)
    }

    /// 猪鹿蝶の札は未取得なら +8。
    @Test func yakuPotentialInoshikacho() {
        let game = makeGame(hand: [], field: [])
        let bonus = HeuristicOpponent.evaluateYakuPotential(
            game: game, seat: .opponent, matches: cards(24), hand: Card.all[26])
        #expect(bonus == 8)
    }

    /// 取得済みの猪鹿蝶札にはボーナスなし。
    @Test func yakuPotentialInoshikachoAlreadyCaptured() {
        let game = makeGame(hand: [], field: [], captured: [24])
        let bonus = HeuristicOpponent.evaluateYakuPotential(
            game: game, seat: .opponent, matches: cards(24), hand: Card.all[26])
        #expect(bonus == 0)
    }

    /// 赤短・青短の札は未取得なら +6。
    @Test func yakuPotentialColorTanzaku() {
        let game = makeGame(hand: [], field: [])
        let akatanBonus = HeuristicOpponent.evaluateYakuPotential(
            game: game, seat: .opponent, matches: cards(1), hand: Card.all[2])
        #expect(akatanBonus == 6)
        let aotanBonus = HeuristicOpponent.evaluateYakuPotential(
            game: game, seat: .opponent, matches: cards(21), hand: Card.all[22])
        #expect(aotanBonus == 6)
    }
}
