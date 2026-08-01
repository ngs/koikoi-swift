import Foundation
import KoikoiCore
import Testing

@testable import KoikoiAI
@testable import KoikoiUI

@MainActor
@Suite struct GameViewModelTests {
    private func makeModel(seed: UInt64) -> GameViewModel {
        GameViewModel(rounds: 1, difficulty: .normal, seed: seed, aiStepDelay: .zero)
    }

    /// 相手の手番が終わるのを待つ。
    private func waitForPlayerPrompt(_ model: GameViewModel) async {
        for _ in 0..<200 where model.prompt == .opponentTurn {
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

        let model = GameViewModel(rounds: 1, difficulty: .normal, seed: 1, aiStepDelay: .zero)
        model.overrideForTesting(game: game)

        #expect(model.prompt == .selectHand)
        model.tapHandCard(Card.all[0])
        #expect(model.pendingHandCard == Card.all[0])
        #expect(model.fieldCandidates == [Card.all[2], Card.all[3]])

        model.cancelFieldSelection()
        #expect(model.prompt == .selectHand)
        #expect(model.pendingHandCard == nil)

        model.tapHandCard(Card.all[0])
        model.tapFieldCard(Card.all[3])
        #expect(model.game.captured(for: .player).contains(Card.all[3]))
    }
}
