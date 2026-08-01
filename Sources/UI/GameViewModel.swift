import Foundation
import KoikoiAI
import KoikoiCore
import Observation

/// 対局画面の進行を司るビューモデル。
/// `RoundSimulator` を 1 ラウンドの状態機械として使い、ラウンドを跨ぐ進行
/// （親の引き継ぎ・得点累積・最終ラウンド判定）は go-koikoi の UI 層と同じ規則で行う。
@MainActor
@Observable
public final class GameViewModel {
    /// UI がプレイヤーに求めている入力。
    public enum Prompt: Equatable {
        /// 手札を選ぶ。
        case selectHand
        /// 場札を選ぶ（2 枚マッチ）。`candidates` のみタップ可能。
        case selectField(candidates: [Card])
        /// こいこいか勝負かを選ぶ。
        case decideKoikoi(newYaku: [Yaku])
        /// 相手の手番（入力不可）。
        case opponentTurn
        /// ラウンド終了の確認待ち。
        case roundEnd(RoundOutcome)
        /// 対局終了。
        case matchEnd(winner: Seat?)
    }

    public private(set) var simulator: RoundSimulator
    public private(set) var prompt: Prompt = .selectHand
    /// 手札 2 枚マッチの場札選択中に保持する手札。
    public private(set) var pendingHandCard: Card?
    /// 相手 AI のひとこと（FoundationModels・不可用時は常に nil）。
    public private(set) var opponentLine: String?

    public let difficulty: Difficulty
    /// AI の手の間に挟む演出ディレイ（テストでは .zero）。
    public var aiStepDelay: Duration

    private var rng: GameRandom
    private let engine = ISMCTSEngine(
        configuration: ISMCTSConfiguration(iterations: 400))
    private let persona = OpponentPersona()
    private var aiTask: Task<Void, Never>?

    public init(
        rounds: Int = 12,
        difficulty: Difficulty = .normal,
        seed: UInt64? = nil,
        aiStepDelay: Duration = .milliseconds(800)
    ) {
        self.difficulty = difficulty
        self.aiStepDelay = aiStepDelay
        var rng = seed.map(GameRandom.init(seed:)) ?? GameRandom()
        var game = Game(rounds: rounds, rng: rng)
        game.startRound()
        _ = rng.next() // 対局用とは別系統の乱数列にする
        self.rng = rng
        simulator = RoundSimulator(game: game)
        syncAfterMutation()
    }

    // MARK: - 読み取り

    public var game: Game { simulator.game }

    /// 選択待ちの場札候補（ハイライト用）。
    public var fieldCandidates: [Card] {
        if case .selectField(let candidates) = prompt { return candidates }
        return []
    }

    /// プレイヤーの現在の役。
    public var playerYaku: [Yaku] {
        YakuChecker.checkYaku(captured: game.captured(for: .player))
    }

    public var opponentYaku: [Yaku] {
        YakuChecker.checkYaku(captured: game.captured(for: .opponent))
    }

    // MARK: - プレイヤー操作

    /// 手札をタップ。2 枚マッチなら場札選択へ、それ以外は即座に出す。
    public func tapHandCard(_ card: Card) {
        guard prompt == .selectHand, case .selectHand(.player) = simulator.phase else { return }
        guard game.hand(for: .player).contains(card) else { return }

        let matches = game.matchingFieldCards(for: card)
        if matches.count == 2 {
            pendingHandCard = card
            prompt = .selectField(candidates: matches)
        } else {
            apply(.playHand(handID: card.id, fieldChoiceID: nil))
        }
    }

    /// 場札をタップ（2 枚マッチの選択）。
    public func tapFieldCard(_ card: Card) {
        guard case .selectField(let candidates) = prompt, candidates.contains(card) else { return }
        if let handCard = pendingHandCard {
            pendingHandCard = nil
            apply(.playHand(handID: handCard.id, fieldChoiceID: card.id))
        } else if case .selectDrawnField = simulator.phase {
            apply(.chooseDrawnField(fieldID: card.id))
        }
    }

    /// 手札 2 枚マッチの場札選択をやめて手札選択に戻る。
    public func cancelFieldSelection() {
        guard pendingHandCard != nil else { return }
        pendingHandCard = nil
        prompt = .selectHand
    }

    /// こいこい（続行）か勝負（終了）を選ぶ。
    public func decide(koikoi: Bool) {
        guard case .decideKoikoi = prompt else { return }
        apply(koikoi ? .koikoi : .shobu)
        if koikoi {
            requestPersonaLine(.playerKoikoi)
        }
    }

    /// ラウンド終了画面から次へ進む。
    public func proceedAfterRound() {
        guard case .roundEnd = prompt else { return }
        var game = simulator.game
        if game.round >= game.maxRounds {
            prompt = .matchEnd(winner: matchWinner(of: game))
            requestPersonaLine(.gameEnd(selfWon: matchWinner(of: game).map { $0 == .opponent }))
            return
        }
        game.round += 1
        game.startRound()
        simulator = RoundSimulator(game: game)
        syncAfterMutation()
    }

    private func matchWinner(of game: Game) -> Seat? {
        let player = game.score(for: .player)
        let opponent = game.score(for: .opponent)
        if player == opponent { return nil }
        return player > opponent ? .player : .opponent
    }

    // MARK: - 進行

    private func apply(_ move: Move) {
        simulator.apply(move)
        syncAfterMutation()
    }

    /// シミュレータの状態から次のプロンプトを決め、必要なら AI 手番を開始する。
    private func syncAfterMutation() {
        switch simulator.phase {
        case .selectHand(.player):
            prompt = .selectHand
        case .selectDrawnField(.player, _, let matches):
            prompt = .selectField(candidates: matches)
        case .decideKoikoi(.player, let newYaku):
            prompt = .decideKoikoi(newYaku: newYaku)
        case .selectHand(.opponent), .selectDrawnField(.opponent, _, _),
            .decideKoikoi(.opponent, _):
            prompt = .opponentTurn
            scheduleOpponentTurn()
        case .finished(let outcome):
            prompt = .roundEnd(outcome)
            aiTask?.cancel()
            announceRoundEnd(outcome)
        }
    }

    /// 相手の決定点が続く限り AI で 1 手ずつ進める。
    private func scheduleOpponentTurn() {
        guard aiTask == nil || aiTask?.isCancelled != false else { return }
        aiTask = Task { [weak self] in
            await self?.runOpponentTurn()
            self?.aiTask = nil
        }
    }

    private func runOpponentTurn() async {
        while simulator.seatToMove == .opponent, !Task.isCancelled {
            try? await Task.sleep(for: aiStepDelay)
            guard !Task.isCancelled, simulator.seatToMove == .opponent else { return }

            let move = await computeOpponentMove()
            guard let move, simulator.seatToMove == .opponent else { return }
            if case .koikoi = move {
                requestPersonaLine(personaKoikoiEvent())
            }
            simulator.apply(move)

            if case .finished = simulator.phase {
                break
            }
        }
        if !Task.isCancelled {
            syncOpponentDone()
        }
    }

    /// AI 手番終了後のプロンプト同期（selectHand(player) などへ戻す）。
    private func syncOpponentDone() {
        if simulator.seatToMove != .opponent {
            syncAfterMutation()
        }
    }

    private func computeOpponentMove() async -> Move? {
        let simulator = self.simulator
        let difficulty = self.difficulty
        let engine = self.engine
        let localRng = rng
        _ = rng.next() // 次回のために状態を進める

        let move: Move? = await Task.detached(priority: .userInitiated) {
            var rng = localRng
            if difficulty == .search {
                return engine.chooseMove(in: simulator, for: .opponent, rng: &rng)
            }
            return simulator.heuristicMove(difficulty: difficulty, rng: &rng)
        }.value
        return move
    }

    // MARK: - 人格（台詞）

    private func personaKoikoiEvent() -> PersonaEvent {
        if case .decideKoikoi(_, let newYaku) = simulator.phase {
            return .selfKoikoi(newYaku: newYaku, handCount: game.hand(for: .opponent).count)
        }
        return .selfKoikoi(newYaku: [], handCount: game.hand(for: .opponent).count)
    }

    private func announceRoundEnd(_ outcome: RoundOutcome) {
        switch outcome.winner {
        case .opponent:
            requestPersonaLine(.selfShobu(points: outcome.points))
        case .player:
            requestPersonaLine(.playerShobu(points: outcome.points))
        case nil:
            requestPersonaLine(.roundDrawn)
        }
    }

    private func requestPersonaLine(_ event: PersonaEvent) {
        guard OpponentPersona.isAvailable else { return }
        let persona = self.persona
        Task { [weak self] in
            let line = await persona.comment(on: event)
            self?.opponentLine = line
        }
    }

    // MARK: - テスト用フック

    /// テスト用: 任意のゲーム状態でラウンドを差し替える。
    func overrideForTesting(game: Game) {
        aiTask?.cancel()
        aiTask = nil
        simulator = RoundSimulator(game: game)
        syncAfterMutation()
    }

    /// テスト用: このシードで親（先攻）がプレイヤーになるか。
    nonisolated static func isPlayerParent(seed: UInt64, rounds: Int) -> Bool {
        Game(rounds: rounds, rng: GameRandom(seed: seed)).nextParent == .player
    }
}
