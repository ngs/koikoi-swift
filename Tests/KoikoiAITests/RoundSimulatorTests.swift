import Testing

@testable import KoikoiAI
@testable import KoikoiCore

@Suite struct RoundSimulatorTests {
    /// 素の状態を作る（親決めだけ済んだ空ゲーム）。
    private func emptyGame(seed: UInt64 = 1) -> Game {
        var game = Game(rounds: 1, rng: GameRandom(seed: seed))
        game.setHand([], for: .player)
        game.setHand([], for: .opponent)
        game.field = []
        game.deck = []
        game.currentTurn = .player
        return game
    }

    /// 手札を出して山札を引いたあと役がなければターン交代する。
    @Test func turnPassesWithoutYaku() {
        var game = emptyGame()
        game.setHand(cards(47), for: .player)
        game.setHand(cards(46), for: .opponent)
        game.deck = cards(3)
        game.field = []

        var sim = RoundSimulator(game: game)
        #expect(sim.phase == .selectHand(.player))
        #expect(sim.legalMoves() == [.playHand(handID: 47, fieldChoiceID: nil)])

        sim.apply(.playHand(handID: 47, fieldChoiceID: nil))
        // 47 → 場、山札 3 → 場、役なし → 相手番
        #expect(sim.phase == .selectHand(.opponent))
        #expect(sim.game.field == cards(47, 3))
        #expect(sim.game.currentTurn == .opponent)
    }

    /// 赤短完成 + 手札なしは自動勝負（go-koikoi と同じ）。
    @Test func autoShobuWhenHandEmpty() {
        var game = emptyGame()
        game.setHand(cards(1), for: .player)  // 松に赤短
        game.setHand(cards(46), for: .opponent)
        game.captured[.player] = cards(5, 9)  // 梅・桜の赤短
        game.field = cards(2)  // 松カス（マッチ相手）
        game.deck = cards(47)  // 桐カス（マッチなし）

        var sim = RoundSimulator(game: game)
        sim.apply(.playHand(handID: 1, fieldChoiceID: nil))

        #expect(sim.isFinished)
        #expect(sim.outcome == RoundOutcome(winner: .player, points: 5))
        #expect(sim.game.score(for: .player) == 5)
        #expect(sim.game.nextParent == .player)
    }

    /// 役成立 + 手札ありはこいこい判断フェーズに入る。
    @Test func koikoiDecisionPhase() {
        var game = emptyGame()
        game.setHand(cards(1, 47), for: .player)
        game.setHand(cards(3), for: .opponent)
        game.captured[.player] = cards(5, 9)
        game.field = cards(2)
        game.deck = cards(46)

        var sim = RoundSimulator(game: game)
        sim.apply(.playHand(handID: 1, fieldChoiceID: nil))

        guard case .decideKoikoi(.player, let newYaku) = sim.phase else {
            Issue.record("expected decideKoikoi, got \(sim.phase)")
            return
        }
        #expect(newYaku == [Yaku(.akatan, 5)])
        #expect(sim.legalMoves() == [.koikoi, .shobu])
    }

    /// こいこい宣言でフラグと役スナップショットを更新しターン交代。
    @Test func koikoiContinues() {
        var game = emptyGame()
        game.setHand(cards(1, 47), for: .player)
        game.setHand(cards(3), for: .opponent)
        game.captured[.player] = cards(5, 9)
        game.field = cards(2)
        game.deck = cards(46)

        var sim = RoundSimulator(game: game)
        sim.apply(.playHand(handID: 1, fieldChoiceID: nil))
        sim.apply(.koikoi)

        #expect(sim.game.koikoiDeclared[.player] == true)
        #expect(sim.game.previousYaku[.player] == [Yaku(.akatan, 5)])
        #expect(sim.phase == .selectHand(.opponent))
    }

    /// 勝負で得点・親を確定してラウンド終了。
    @Test func shobuEndsRound() {
        var game = emptyGame()
        game.setHand(cards(1, 47), for: .player)
        game.setHand(cards(3), for: .opponent)
        game.captured[.player] = cards(5, 9)
        game.field = cards(2)
        game.deck = cards(46)

        var sim = RoundSimulator(game: game)
        sim.apply(.playHand(handID: 1, fieldChoiceID: nil))
        sim.apply(.shobu)

        #expect(sim.outcome == RoundOutcome(winner: .player, points: 5))
        #expect(sim.game.score(for: .player) == 5)
        #expect(sim.game.nextParent == .player)
    }

    /// 両者の手札が尽きたら流局（無得点・親は変わらない）。
    @Test func exhaustionIsDraw() {
        var game = emptyGame()
        let parentBefore = game.nextParent
        game.setHand(cards(47), for: .player)
        game.setHand([], for: .opponent)
        game.deck = cards(3)

        var sim = RoundSimulator(game: game)
        sim.apply(.playHand(handID: 47, fieldChoiceID: nil))

        #expect(sim.outcome == RoundOutcome(winner: nil, points: 0))
        #expect(sim.game.score(for: .player) == 0)
        #expect(sim.game.score(for: .opponent) == 0)
        #expect(sim.game.nextParent == parentBefore)
    }

    /// 手札のない席はターンを飛ばす。
    @Test func skipsEmptyHand() {
        var game = emptyGame()
        game.setHand(cards(2, 3), for: .player)
        game.setHand([], for: .opponent)
        game.deck = cards(46, 47)

        var sim = RoundSimulator(game: game)
        sim.apply(.playHand(handID: 2, fieldChoiceID: nil))

        // 相手は手札なし → 再び自分の番
        #expect(sim.phase == .selectHand(.player))
    }

    /// 山札の引き札が 2 枚マッチしたら場札選択フェーズに入る。
    @Test func drawnCardTwoMatches() {
        var game = emptyGame()
        game.setHand(cards(47), for: .player)
        game.setHand(cards(46), for: .opponent)
        game.field = cards(2, 3)  // 松カス×2
        game.deck = cards(1)  // 松に赤短

        var sim = RoundSimulator(game: game)
        sim.apply(.playHand(handID: 47, fieldChoiceID: nil))

        guard case let .selectDrawnField(.player, drawn, matches) = sim.phase else {
            Issue.record("expected selectDrawnField, got \(sim.phase)")
            return
        }
        #expect(drawn == Card.all[1])
        #expect(matches == cards(2, 3))
        #expect(sim.legalMoves() == [
            .chooseDrawnField(fieldID: 2), .chooseDrawnField(fieldID: 3)
        ])

        sim.apply(.chooseDrawnField(fieldID: 3))
        #expect(sim.game.captured(for: .player) == cards(1, 3))
        #expect(sim.game.field == cards(2, 47))
        #expect(sim.phase == .selectHand(.opponent))
    }

    /// 手札 2 枚マッチは場札の選択ごとに合法手が分かれる。
    @Test func handCardTwoMatchesSplitMoves() {
        var game = emptyGame()
        game.setHand(cards(0), for: .player)  // 松に鶴
        game.setHand(cards(46), for: .opponent)
        game.field = cards(2, 3)  // 松カス×2
        game.deck = cards(47)

        let sim = RoundSimulator(game: game)
        #expect(sim.legalMoves() == [
            .playHand(handID: 0, fieldChoiceID: 2), .playHand(handID: 0, fieldChoiceID: 3)
        ])
    }

    /// ヒューリスティック方策でラウンドが必ず終わり、札は保存される。
    @Test func fullRoundWithHeuristicTerminates() {
        for seed: UInt64 in 1...8 {
            var game = Game(rounds: 1, rng: GameRandom(seed: seed))
            game.startRound()
            var sim = RoundSimulator(game: game)
            var rng = GameRandom(seed: seed &+ 100)

            var steps = 0
            while !sim.isFinished, steps < 200,
                let move = sim.heuristicMove(difficulty: .normal, rng: &rng) {
                sim.apply(move)
                steps += 1
            }

            #expect(sim.isFinished, "seed \(seed) did not finish")
            let endGame = sim.game
            let all = endGame.deck + endGame.field
                + endGame.hand(for: .player) + endGame.hand(for: .opponent)
                + endGame.captured(for: .player) + endGame.captured(for: .opponent)
            #expect(all.count == 48, "seed \(seed) lost cards")
            #expect(Set(all.map(\.id)).count == 48, "seed \(seed) duplicated cards")
        }
    }
}
