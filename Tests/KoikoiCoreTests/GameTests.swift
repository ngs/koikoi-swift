import Testing

@testable import KoikoiCore

@Suite struct GameTests {
    @Test func newGame() throws {
        let game = Game(rounds: 12, rng: GameRandom(seed: 1))
        #expect(game.round == 1)
        #expect(game.maxRounds == 12)
        // 親決めで両者の引き札が記録され、月が異なる
        let playerCard = try #require(game.parentDrawnCards[.player])
        let opponentCard = try #require(game.parentDrawnCards[.opponent])
        #expect(playerCard.month != opponentCard.month)
        // 月が若い方が親
        let expectedParent: Seat =
            playerCard.month.rawValue < opponentCard.month.rawValue ? .player : .opponent
        #expect(game.nextParent == expectedParent)
    }

    /// 親決めはどちらの席も親になりうる。
    @Test func determineParentBothPaths() {
        var seenParents: Set<Seat> = []
        for seed in 0..<64 {
            let game = Game(rounds: 1, rng: GameRandom(seed: UInt64(seed)))
            seenParents.insert(game.nextParent)
            if seenParents.count == 2 { break }
        }
        #expect(seenParents == [.player, .opponent])
    }

    @Test func startRound() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 2))
        game.startRound()
        #expect(game.hand(for: .player).count == 8)
        #expect(game.hand(for: .opponent).count == 8)
        #expect(game.field.count == 8)
        #expect(game.deck.count == 48 - 24)
        #expect(game.captured(for: .player).isEmpty)
        #expect(game.captured(for: .opponent).isEmpty)
        #expect(game.koikoiDeclared[.player] == false)
        #expect(game.koikoiDeclared[.opponent] == false)
    }

    /// 親（前ラウンド勝者）が先攻。
    @Test func startRoundParent() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 3))
        game.nextParent = .opponent
        game.startRound()
        #expect(game.currentTurn == .opponent)

        game.nextParent = .player
        game.startRound()
        #expect(game.currentTurn == .player)
    }

    /// 配札後の全ゾーンで札が重複しない。
    @Test func startRoundAllCardsUnique() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 4))
        game.startRound()
        let all =
            game.deck + game.field + game.hand(for: .player) + game.hand(for: .opponent)
        #expect(all.count == 48)
        #expect(Set(all.map(\.id)).count == 48)
    }

    @Test func drawFromDeck() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 5))
        game.startRound()
        let before = game.deck.count
        let expected = game.deck[0]
        let drawn = game.drawFromDeck()
        #expect(drawn == expected)
        #expect(game.deck.count == before - 1)

        game.deck = []
        #expect(game.drawFromDeck() == nil)
    }

    @Test func matchingFieldCards() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 6))
        game.field = cards(1, 2, 4, 8)  // 松, 松, 梅, 桜
        let matches = game.matchingFieldCards(for: Card.all[0])  // 松に鶴
        #expect(matches == cards(1, 2))
        let noMatches = game.matchingFieldCards(for: Card.all[44])  // 桐に鳳凰
        #expect(noMatches.isEmpty)
    }

    // MARK: - playCard

    @Test func playCardNoMatch() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 7))
        game.hands[.player] = cards(0)
        game.field = cards(4, 8)  // 梅, 桜（松なし）
        let captured = game.playCard(Card.all[0], fieldChoice: nil, by: .player)
        #expect(captured.isEmpty)
        #expect(game.hand(for: .player).isEmpty)
        #expect(game.field == cards(4, 8, 0))  // 場に置かれる
        #expect(game.captured(for: .player).isEmpty)
    }

    @Test func playCardOneMatch() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 8))
        game.hands[.player] = cards(0)
        game.field = cards(1, 4)  // 松に赤短, 梅
        let captured = game.playCard(Card.all[0], fieldChoice: nil, by: .player)
        #expect(captured == cards(0, 1))
        #expect(game.field == cards(4))
        #expect(game.captured(for: .player) == cards(0, 1))
    }

    @Test func playCardTwoMatchWithChoice() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 9))
        game.hands[.player] = cards(0)
        game.field = cards(1, 2, 4)  // 松×2, 梅
        let choice = Card.all[2]
        let captured = game.playCard(Card.all[0], fieldChoice: choice, by: .player)
        #expect(captured == cards(0, 2))
        #expect(game.field == cards(1, 4))
    }

    @Test func playCardTwoMatchNoChoice() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 10))
        game.hands[.player] = cards(0)
        game.field = cards(1, 2, 4)
        let captured = game.playCard(Card.all[0], fieldChoice: nil, by: .player)
        // 未指定なら最初の 1 枚
        #expect(captured == cards(0, 1))
        #expect(game.field == cards(2, 4))
    }

    @Test func playCardThreeMatch() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 11))
        game.hands[.player] = cards(0)
        game.field = cards(1, 2, 3, 4)  // 松×3, 梅
        let captured = game.playCard(Card.all[0], fieldChoice: nil, by: .player)
        // 3枚マッチは全取り
        #expect(Set(captured.map(\.id)) == [0, 1, 2, 3])
        #expect(game.field == cards(4))
    }

    @Test func playCardOpponent() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 12))
        game.hands[.opponent] = cards(0)
        game.field = cards(1, 4)
        let captured = game.playCard(Card.all[0], fieldChoice: nil, by: .opponent)
        #expect(captured == cards(0, 1))
        #expect(game.hand(for: .opponent).isEmpty)
        #expect(game.captured(for: .opponent) == cards(0, 1))
        #expect(game.captured(for: .player).isEmpty)
    }

    // MARK: - playDrawnCard

    @Test func playDrawnCardNoMatch() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 13))
        game.field = cards(4, 8)
        let captured = game.playDrawnCard(Card.all[0], fieldChoice: nil, by: .player)
        #expect(captured.isEmpty)
        #expect(game.field == cards(4, 8, 0))
    }

    @Test func playDrawnCardOneMatch() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 14))
        game.field = cards(1, 4)
        let captured = game.playDrawnCard(Card.all[0], fieldChoice: nil, by: .player)
        #expect(captured == cards(0, 1))
        #expect(game.captured(for: .player) == cards(0, 1))
    }

    @Test func playDrawnCardTwoMatchWithChoice() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 15))
        game.field = cards(1, 2, 4)
        let captured = game.playDrawnCard(Card.all[0], fieldChoice: Card.all[2], by: .player)
        #expect(captured == cards(0, 2))
        #expect(game.field == cards(1, 4))
    }

    @Test func playDrawnCardTwoMatchNoChoice() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 16))
        game.field = cards(1, 2, 4)
        let captured = game.playDrawnCard(Card.all[0], fieldChoice: nil, by: .player)
        #expect(captured == cards(0, 1))
    }

    @Test func playDrawnCardThreeMatch() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 17))
        game.field = cards(1, 2, 3, 4)
        let captured = game.playDrawnCard(Card.all[0], fieldChoice: nil, by: .player)
        #expect(Set(captured.map(\.id)) == [0, 1, 2, 3])
        #expect(game.field == cards(4))
    }

    @Test func playDrawnCardOpponent() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 18))
        game.field = cards(1, 4)
        let captured = game.playDrawnCard(Card.all[0], fieldChoice: nil, by: .opponent)
        #expect(captured == cards(0, 1))
        #expect(game.captured(for: .opponent) == cards(0, 1))
    }

    // MARK: - 役チェック

    @Test func checkNewYakuPlayer() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 19))
        game.captured[.player] = cards(0, 8, 28)  // 三光
        let newYaku = game.checkNewYaku(for: .player)
        #expect(newYaku.contains(Yaku(.sankou, 5)))
    }

    @Test func checkNewYakuOpponent() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 20))
        game.captured[.opponent] = cards(1, 5, 9)  // 赤短
        let newYaku = game.checkNewYaku(for: .opponent)
        #expect(newYaku.contains(Yaku(.akatan, 5)))
    }

    /// 前回チェック済みの役は「新しい役」に含めない。
    @Test func checkNewYakuNoNew() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 21))
        game.captured[.player] = cards(0, 8, 28)
        game.updatePreviousYaku(for: .player)
        #expect(game.checkNewYaku(for: .player).isEmpty)
    }

    /// 同名役でも点数が上がれば「新しい役」になる（役のアップグレード）。
    @Test func checkNewYakuUpgraded() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 22))
        game.captured[.player] = cards(1, 5, 9)  // 赤短 5文
        game.updatePreviousYaku(for: .player)
        game.captured[.player] = cards(1, 5, 9, 13)  // 赤短 6文
        let newYaku = game.checkNewYaku(for: .player)
        #expect(newYaku.contains(Yaku(.akatan, 6)))
    }

    @Test func updatePreviousYaku() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 23))
        game.captured[.player] = cards(0, 8, 28)
        game.updatePreviousYaku(for: .player)
        #expect(game.previousYaku[.player] == [Yaku(.sankou, 5)])
    }

    // MARK: - 得点計算

    @Test func calcFinalScoreBasic() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 24))
        game.captured[.player] = cards(0, 8, 28)  // 三光 5文
        #expect(game.calcFinalScore(for: .player) == 5)
    }

    /// 7 文以上で 2 倍。
    @Test func calcFinalScoreDoubling() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 25))
        game.captured[.player] = cards(0, 8, 28, 44)  // 四光 8文
        #expect(game.calcFinalScore(for: .player) == 16)
    }

    /// 相手こいこい中の上がりは 2 倍。
    @Test func calcFinalScoreKoikoiPenalty() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 26))
        game.captured[.player] = cards(0, 8, 28)  // 5文
        game.koikoiDeclared[.opponent] = true
        #expect(game.calcFinalScore(for: .player) == 10)
    }

    /// 7 文以上 × 相手こいこいで 4 倍。
    @Test func calcFinalScoreDoublingAndKoikoi() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 27))
        game.captured[.player] = cards(0, 8, 28, 44)  // 8文
        game.koikoiDeclared[.opponent] = true
        #expect(game.calcFinalScore(for: .player) == 32)
    }

    @Test func calcFinalScoreOpponent() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 28))
        game.captured[.opponent] = cards(0, 8, 28)
        game.koikoiDeclared[.player] = true
        #expect(game.calcFinalScore(for: .opponent) == 10)
    }

    // MARK: - その他

    @Test func isRoundOver() {
        var game = Game(rounds: 12, rng: GameRandom(seed: 29))
        game.hands[.player] = cards(0)
        game.hands[.opponent] = []
        #expect(!game.isRoundOver)
        game.hands[.player] = []
        #expect(game.isRoundOver)
    }

    @Test func removingCard() {
        let removed = cards(0, 1, 2).removingCard(Card.all[1])
        #expect(removed == cards(0, 2))
    }

    @Test func removingCardNotFound() {
        let unchanged = cards(0, 1).removingCard(Card.all[44])
        #expect(unchanged == cards(0, 1))
    }

    /// シード付き RNG は同一進行を再現する（MCTS の決定論の前提）。
    @Test func seededGameIsDeterministic() {
        var first = Game(rounds: 12, rng: GameRandom(seed: 42))
        var second = Game(rounds: 12, rng: GameRandom(seed: 42))
        first.startRound()
        second.startRound()
        #expect(first == second)
    }
}
