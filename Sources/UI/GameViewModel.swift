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

    /// 十字キー操作のカーソル位置。
    public enum Cursor: Equatable {
        case hand(Int)
        case field(Int)
    }

    /// 十字キーの移動方向。
    public enum MoveDirection {
        case up, down, left, right
    }

    public private(set) var simulator: RoundSimulator
    public private(set) var prompt: Prompt = .selectHand
    /// 手札 2 枚マッチの場札選択中に保持する手札。
    public private(set) var pendingHandCard: Card?
    /// 相手 AI のひとこと（FoundationModels・不可用時は常に nil）。
    public private(set) var opponentLine: String?
    /// 十字キー操作のカーソル（キー入力があるまで nil）。
    public private(set) var cursor: Cursor?
    /// こいこいダイアログでキー選択中の側（true = こいこい）。
    public private(set) var dialogKoikoiSelected = true
    /// ポインタホバー中の手札（macOS/iPad。場札ハイライトの参照元）。
    public var hoverHandCard: Card?

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

    /// プレイヤーのリーチ（あと 1 枚で成立する役。go-koikoi の mycap 表示と同じ）。
    public var playerReaches: [YakuReach] {
        YakuChecker.checkReach(
            captured: game.captured(for: .player),
            opponentCaptured: game.captured(for: .opponent))
    }

    /// 場札ハイライトの参照になっている手札
    /// （場札選択中の保持札 > キーカーソル > ホバーの優先順）。
    public var previewHandCard: Card? {
        if let pendingHandCard { return pendingHandCard }
        guard prompt == .selectHand else { return nil }
        if case .hand(let index) = cursor {
            let hand = game.hand(for: .player)
            if hand.indices.contains(index) { return hand[index] }
        }
        return hoverHandCard
    }

    /// ハイライトすべき場札（選択候補、なければプレビュー手札のマッチ）。
    public var highlightedFieldCards: [Card] {
        if !fieldCandidates.isEmpty { return fieldCandidates }
        if let preview = previewHandCard {
            return game.matchingFieldCards(for: preview)
        }
        return []
    }

    /// 場札選択中か（候補以外の場札を減光する）。
    public var isSelectingField: Bool {
        if case .selectField = prompt { return true }
        return false
    }

    /// 山札から引いた札（場札選択中のみ・表示用）。
    public var drawnCard: Card? {
        if case .selectDrawnField(_, let drawn, _) = simulator.phase { return drawn }
        return nil
    }

    // MARK: - プレイヤー操作

    /// 手札をタップ。2 枚マッチなら場札選択へ、それ以外は即座に出す。
    /// 場札選択中は、同じ札で選択解除・別の札で選び直しになる。
    public func tapHandCard(_ card: Card) {
        if let pending = pendingHandCard {
            pendingHandCard = nil
            prompt = .selectHand
            if card == pending { return }  // トグルで解除
        }
        guard prompt == .selectHand, case .selectHand(.player) = simulator.phase else { return }
        guard game.hand(for: .player).contains(card) else { return }

        let matches = game.matchingFieldCards(for: card)
        if matches.count == 2 {
            pendingHandCard = card
            prompt = .selectField(candidates: matches)
            syncCursor()
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

    /// 手札をドラッグして場（`target` = 場札、nil = 空きへの捨て札）に落とす。
    /// - Returns: 合法で適用されたら true（false はドロップ拒否）。
    @discardableResult
    public func dropHandCard(id: Int?, on target: Card?) -> Bool {
        guard case .selectHand(.player) = simulator.phase else { return false }
        guard let id, let card = game.hand(for: .player).first(where: { $0.id == id }) else {
            return false
        }
        let matches = game.matchingFieldCards(for: card)
        if let target {
            guard matches.contains(target) else { return false }
            pendingHandCard = nil
            apply(.playHand(handID: card.id, fieldChoiceID: target.id))
        } else {
            // マッチのある札は場札を指定して落とす（誤操作の捨て札を防ぐ）
            guard matches.isEmpty else { return false }
            pendingHandCard = nil
            apply(.playHand(handID: card.id, fieldChoiceID: nil))
        }
        return true
    }

    // MARK: - 十字キー操作

    /// カーソルを移動する。
    public func moveCursor(_ direction: MoveDirection) {
        switch prompt {
        case .selectHand:
            let handCount = game.hand(for: .player).count
            guard handCount > 0 else { return }
            let current: Int = if case .hand(let index) = cursor { index } else { -1 }
            cursor = .hand(step(current, direction: direction, count: handCount))
        case .selectField(let candidates):
            guard !candidates.isEmpty else { return }
            let indices = candidates.compactMap { candidate in
                game.field.firstIndex(of: candidate)
            }
            guard !indices.isEmpty else { return }
            let position: Int = if case .field(let index) = cursor,
                let found = indices.firstIndex(of: index) { found } else { -1 }
            let next = step(position, direction: direction, count: indices.count)
            cursor = .field(indices[next])
        case .decideKoikoi:
            if direction == .left || direction == .right {
                dialogKoikoiSelected.toggle()
            }
        case .opponentTurn, .roundEnd, .matchEnd:
            break
        }
    }

    /// カーソル位置を決定する（Enter / Space）。
    public func activateCursor() {
        switch prompt {
        case .selectHand:
            if case .hand(let index) = cursor {
                let hand = game.hand(for: .player)
                if hand.indices.contains(index) {
                    tapHandCard(hand[index])
                }
            }
        case .selectField:
            if case .field(let index) = cursor, game.field.indices.contains(index) {
                tapFieldCard(game.field[index])
            }
        case .decideKoikoi:
            decide(koikoi: dialogKoikoiSelected)
        case .roundEnd:
            proceedAfterRound()
        case .opponentTurn, .matchEnd:
            break
        }
    }

    /// 前後移動の共通処理（wrap あり。上下も 1 ステップ扱い）。
    private func step(_ current: Int, direction: MoveDirection, count: Int) -> Int {
        let delta = (direction == .left || direction == .up) ? -1 : 1
        if current < 0 {
            return delta > 0 ? 0 : count - 1
        }
        return (current + delta + count) % count
    }

    /// プロンプト遷移に応じてカーソルを補正する。
    private func syncCursor() {
        switch prompt {
        case .selectHand:
            if case .hand(let index) = cursor {
                let handCount = game.hand(for: .player).count
                cursor = handCount > 0 ? .hand(min(index, handCount - 1)) : nil
            } else if cursor != nil {
                cursor = .hand(0)
            }
        case .selectField(let candidates):
            if let first = candidates.first, let index = game.field.firstIndex(of: first) {
                cursor = .field(index)
            }
        case .decideKoikoi:
            dialogKoikoiSelected = true
            cursor = nil
        case .opponentTurn, .roundEnd, .matchEnd:
            cursor = nil
        }
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
            aiTask = nil
            announceRoundEnd(outcome)
        }
        syncCursor()
    }

    /// 相手の決定点が続く限り AI で 1 手ずつ進める。
    /// 既存タスクは必ずキャンセルして置き換える（自身で aiTask を消さないので
    /// 古いタスクが新しいタスクの参照を消す競合は起きない）。
    private func scheduleOpponentTurn() {
        aiTask?.cancel()
        aiTask = Task { [weak self] in
            await self?.runOpponentTurn()
        }
    }

    private func runOpponentTurn() async {
        while simulator.seatToMove == .opponent, !Task.isCancelled {
            try? await Task.sleep(for: aiStepDelay)
            guard !Task.isCancelled, simulator.seatToMove == .opponent else { return }

            let move = await computeOpponentMove()
            // 探索の await 中にキャンセル・置き換えされた可能性があるため再確認する
            guard !Task.isCancelled, let move, simulator.seatToMove == .opponent else { return }
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
