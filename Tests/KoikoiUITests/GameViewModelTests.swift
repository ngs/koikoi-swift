import Foundation
import KoikoiCore
import Testing

@testable import KoikoiAI
@testable import KoikoiUI

@MainActor
@Suite struct GameViewModelTests {
    private func makeModel(seed: UInt64) -> GameViewModel {
        GameViewModel(rounds: 1, difficulty: .normal, seed: seed, aiStepDelay: .zero, captureAnimationsEnabled: false)
    }

    /// 相手の手番が終わるのを待つ（上限 2 秒）。
    private func waitForPlayerPrompt(_ model: GameViewModel) async {
        var iterations = 0
        while model.prompt == .opponentTurn, iterations < 200 {
            iterations += 1
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// ラウンド 1 局をプレイヤー先頭手 + AI で最後まで進められる。
    @Test func playsThroughARound() async {
        // 親がプレイヤーになるシードを使う
        var model: GameViewModel?
        for seed: UInt64 in 1...16 where GameViewModel.isPlayerParent(seed: seed, rounds: 1) {
            model = makeModel(seed: seed)
            break
        }
        guard let model else {
            Issue.record("no player-parent seed found")
            return
        }

        var guardCount = 0
        while guardCount < 100 {
            guardCount += 1
            await waitForPlayerPrompt(model)
            switch model.prompt {
            case .selectHand:
                guard let card = model.game.hand(for: .player).first else {
                    Issue.record("empty hand at selectHand")
                    return
                }
                model.tapHandCard(card)
            case .selectField(let candidates):
                guard let choice = candidates.first else {
                    Issue.record("no field candidates")
                    return
                }
                model.tapFieldCard(choice)
            case .decideKoikoi:
                model.decide(koikoi: false)
            case .opponentTurn:
                continue
            case .roundEnd:
                model.proceedAfterRound()
            case .matchEnd:
                return  // 1 局対局なので roundEnd → matchEnd で終わり
            }
        }
        Issue.record("round did not finish: \(model.prompt)")
    }

    /// 2 枚マッチの手札タップは場札選択に遷移し、キャンセルで戻れる。
    @Test func fieldSelectionFlow() async {
        // 状態を直接組んで検証する
        var game = Game(rounds: 1, rng: GameRandom(seed: 1))
        game.setHand([Card.all[0]], for: .player)  // 松に鶴
        game.setHand([Card.all[46]], for: .opponent)
        game.field = [Card.all[2], Card.all[3]]  // 松カス×2
        game.deck = [Card.all[47]]
        game.currentTurn = .player

        let model = GameViewModel(rounds: 1, difficulty: .normal, seed: 1, aiStepDelay: .zero, captureAnimationsEnabled: false)
        model.overrideForTesting(game: game)

        #expect(model.prompt == .selectHand)
        model.tapHandCard(Card.all[0])
        #expect(model.pendingHandCard == Card.all[0])
        #expect(model.fieldCandidates == [Card.all[2], Card.all[3]])

        model.cancelFieldSelection()
        #expect(model.prompt == .selectHand)
        #expect(model.pendingHandCard == nil)

        // 同じ手札の再タップでも選択解除できる（トグル）
        model.tapHandCard(Card.all[0])
        #expect(model.pendingHandCard == Card.all[0])
        model.tapHandCard(Card.all[0])
        #expect(model.pendingHandCard == nil)
        #expect(model.prompt == .selectHand)

        model.tapHandCard(Card.all[0])
        model.tapFieldCard(Card.all[3])
        #expect(model.game.captured(for: .player).contains(Card.all[3]))
    }

    /// ドラッグ&ドロップ: マッチする場札への直接ドロップと不正ドロップの拒否。
    @Test func dragAndDrop() {
        var game = Game(rounds: 1, rng: GameRandom(seed: 1))
        game.setHand([Card.all[0], Card.all[47]], for: .player)  // 松に鶴・桐カス
        game.setHand([Card.all[46]], for: .opponent)
        game.field = [Card.all[2], Card.all[3], Card.all[4]]  // 松カス×2・梅
        game.deck = [Card.all[45]]
        game.currentTurn = .player

        let model = GameViewModel(rounds: 1, difficulty: .normal, seed: 1, aiStepDelay: .zero, captureAnimationsEnabled: false)
        model.overrideForTesting(game: game)

        // マッチしない場札へのドロップは拒否
        #expect(!model.dropHandCard(id: 0, on: Card.all[4]))
        // マッチのある札の空きドロップ（捨て札）は拒否
        #expect(!model.dropHandCard(id: 0, on: nil))
        // マッチする場札へは 2 枚マッチでも直接指定できる
        #expect(model.dropHandCard(id: 0, on: Card.all[3]))
        #expect(model.game.captured(for: .player).contains(Card.all[3]))
    }

    /// マッチのない手札は空きへのドロップで捨て札にできる。
    @Test func dragAndDropDiscard() {
        var game = Game(rounds: 1, rng: GameRandom(seed: 1))
        game.setHand([Card.all[47]], for: .player)  // 桐カス（マッチなし）
        game.setHand([Card.all[46]], for: .opponent)
        game.field = [Card.all[4]]
        game.deck = [Card.all[6]]  // 梅カス（捨てた桐を引き札が回収しないように）
        game.currentTurn = .player

        let model = GameViewModel(rounds: 1, difficulty: .normal, seed: 1, aiStepDelay: .zero, captureAnimationsEnabled: false)
        model.overrideForTesting(game: game)

        #expect(model.dropHandCard(id: 47, on: nil))
        #expect(model.game.field.contains(Card.all[47]))
    }

    /// 十字キー: 手札カーソルの移動・決定と、場札選択での候補巡回。
    @Test func cursorNavigation() {
        var game = Game(rounds: 1, rng: GameRandom(seed: 1))
        game.setHand([Card.all[0], Card.all[47]], for: .player)
        game.setHand([Card.all[46]], for: .opponent)
        game.field = [Card.all[4], Card.all[2], Card.all[3]]  // 梅・松カス×2
        game.deck = [Card.all[45]]
        game.currentTurn = .player

        let model = GameViewModel(rounds: 1, difficulty: .normal, seed: 1, aiStepDelay: .zero, captureAnimationsEnabled: false)
        model.overrideForTesting(game: game)

        model.moveCursor(.right)
        #expect(model.cursor == .hand(0))
        // カーソル中の手札のマッチが場札ハイライトに反映される（go-koikoi 踏襲）
        #expect(model.highlightedFieldCards == [Card.all[2], Card.all[3]])
        model.moveCursor(.right)
        #expect(model.cursor == .hand(1))
        model.moveCursor(.right)  // wrap
        #expect(model.cursor == .hand(0))

        // 決定 → 2 枚マッチなので場札選択へ。カーソルは先頭候補（field[1]）へ
        model.activateCursor()
        #expect(model.pendingHandCard == Card.all[0])
        #expect(model.cursor == .field(1))
        // 候補内だけを巡回する（梅 field[0] はスキップ）
        model.moveCursor(.right)
        #expect(model.cursor == .field(2))
        model.moveCursor(.right)
        #expect(model.cursor == .field(1))

        model.activateCursor()
        #expect(model.game.captured(for: .player).contains(Card.all[2]))
    }
}

extension GameViewModelTests {
    /// 記録（onMoveApplied）→ JSON 往復 → リプレイで同一盤面が復元される。
    @Test func recordAndReplayRoundTrip() async throws {
        let model = makeModel(seed: 5)
        var moves: [Move] = []
        model.onMoveApplied = { moves.append($0) }

        // プレイヤーの手を数手進める（AI 手番の完了は毎回待つ）
        var plays = 0
        var guardCount = 0
        while plays < 4, guardCount < 50 {
            guardCount += 1
            await waitForPlayerPrompt(model)
            switch model.prompt {
            case .selectHand:
                guard let card = model.game.hand(for: .player).first else { break }
                model.tapHandCard(card)
                plays += 1
            case .selectField(let candidates):
                model.tapFieldCard(candidates[0])
            case .decideKoikoi:
                model.decide(koikoi: false)
            case .roundEnd, .matchEnd:
                plays = 4
            case .opponentTurn:
                continue
            }
        }
        await waitForPlayerPrompt(model)
        guard model.prompt != .opponentTurn else {
            Issue.record("AI turn did not finish")
            return
        }

        // JSON 往復
        let record = model.makeRecord(moves: moves)
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(GameRecord.self, from: data)
        #expect(decoded == record)
        #expect(!record.moves.isEmpty)

        // リプレイ復元
        let replayed = GameViewModel(
            record: decoded, aiStepDelay: .zero, captureAnimationsEnabled: false)
        #expect(replayed.game == model.game)
        #expect(replayed.prompt == model.prompt)
    }
}
