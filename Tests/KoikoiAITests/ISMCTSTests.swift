import Testing

@testable import KoikoiAI
@testable import KoikoiCore

@Suite struct ISMCTSTests {
    /// 素の状態を作る（親決めだけ済んだ空ゲーム）。
    private func emptyGame(seed: UInt64 = 1) -> Game {
        var game = Game(rounds: 1, rng: GameRandom(seed: seed))
        game.setHand([], for: .player)
        game.setHand([], for: .opponent)
        game.field = []
        game.deck = []
        game.currentTurn = .opponent
        return game
    }

    /// 合法手が 1 つなら探索せず即返す。
    @Test func singleLegalMoveShortCircuits() {
        var game = emptyGame()
        game.setHand(cards(47), for: .opponent)
        game.setHand(cards(46), for: .player)
        game.deck = cards(3)

        let sim = RoundSimulator(game: game)
        var rng = GameRandom(seed: 1)
        let engine = ISMCTSEngine(configuration: ISMCTSConfiguration(iterations: 1))
        let move = engine.chooseMove(in: sim, for: .opponent, rng: &rng)
        #expect(move == .playHand(handID: 47, fieldChoiceID: nil))
    }

    /// 手番でない席からの問い合わせは nil。
    @Test func rejectsWrongSeat() {
        var game = emptyGame()
        game.setHand(cards(47), for: .opponent)

        let sim = RoundSimulator(game: game)
        var rng = GameRandom(seed: 1)
        let engine = ISMCTSEngine()
        #expect(engine.chooseMove(in: sim, for: .player, rng: &rng) == nil)
    }

    /// 相手のリーチ札を取って阻止する手を、捨て札より優先する。
    /// （放置すると相手が三光で即上がりする局面）
    @Test func blocksOpponentSankou() {
        var game = emptyGame()
        // AI (.opponent) の手札: 桐カス（場の桐に鳳凰を取れる）/ 松カス（捨て札）
        game.setHand(cards(47, 2), for: .opponent)
        // プレイヤーは桐カスを持ち、光 2 枚獲得済み → 桐に鳳凰で三光
        game.setHand(cards(45), for: .player)
        game.captured[.player] = cards(0, 28)
        game.field = cards(44, 10)  // 桐に鳳凰・桜カス
        game.deck = cards(3, 6)

        let sim = RoundSimulator(game: game)
        var rng = GameRandom(seed: 7)
        let engine = ISMCTSEngine(configuration: ISMCTSConfiguration(iterations: 400))
        let move = engine.chooseMove(in: sim, for: .opponent, rng: &rng)
        #expect(move == .playHand(handID: 47, fieldChoiceID: nil))
    }

    /// 高得点確定時はこいこいより勝負を選ぶ（勝負 = 確実な最大報酬）。
    @Test func prefersShobuWithLockedWin() {
        var game = emptyGame()
        game.setHand(cards(2), for: .opponent)
        game.setHand(cards(3, 6), for: .player)
        // 五光 10 文 → 7 文以上で 2 倍 = 20 文
        game.captured[.opponent] = cards(0, 8, 28, 40, 44)
        game.deck = cards(46, 47, 45)

        let sim = RoundSimulator(
            game: game, phase: .decideKoikoi(.opponent, newYaku: [Yaku(.gokou, 10)]))
        var rng = GameRandom(seed: 5)
        let engine = ISMCTSEngine(configuration: ISMCTSConfiguration(iterations: 300))
        let move = engine.chooseMove(in: sim, for: .opponent, rng: &rng)
        #expect(move == .shobu)
    }

    /// 同じシードなら同じ手を返す（決定性）。
    @Test func deterministicGivenSeed() {
        var game = Game(rounds: 1, rng: GameRandom(seed: 21))
        game.startRound()
        let sim = RoundSimulator(game: game)
        let seat = game.currentTurn

        let engine = ISMCTSEngine(configuration: ISMCTSConfiguration(iterations: 100))
        var rng1 = GameRandom(seed: 9)
        var rng2 = GameRandom(seed: 9)
        let move1 = engine.chooseMove(in: sim, for: seat, rng: &rng1)
        let move2 = engine.chooseMove(in: sim, for: seat, rng: &rng2)
        #expect(move1 == move2)
        #expect(move1 != nil)
    }

    /// 実配札のラウンドを ISMCTS（自分）× ヒューリスティック（相手）で
    /// 最後まで進められる（統合スモーク）。
    @Test func playsFullRoundAgainstHeuristic() {
        var game = Game(rounds: 1, rng: GameRandom(seed: 31))
        game.startRound()
        var sim = RoundSimulator(game: game)
        var rng = GameRandom(seed: 32)
        let engine = ISMCTSEngine(configuration: ISMCTSConfiguration(iterations: 60))

        var steps = 0
        while !sim.isFinished, steps < 200 {
            guard let seat = sim.seatToMove else { break }
            let move: Move? = seat == .opponent
                ? engine.chooseMove(in: sim, for: seat, rng: &rng)
                : sim.heuristicMove(difficulty: .normal, rng: &rng)
            guard let move else { break }
            sim.apply(move)
            steps += 1
        }

        #expect(sim.isFinished)
        let outcome = sim.outcome
        #expect(outcome != nil)
        if let outcome, let winner = outcome.winner {
            #expect(sim.game.score(for: winner) == outcome.points)
        }
    }
}
