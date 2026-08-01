import Foundation
import KoikoiCore

/// ラウンド進行上の決定点で選べる 1 手。
/// 選択の発生しない進行（山札 0/1/3 枚マッチの解決など）は
/// `RoundSimulator` が自動で進めるため、ここには現れない。
public enum Move: Sendable, Hashable {
    /// 手札を出す（2 枚マッチ時は場札の選択も含む）。
    case playHand(handID: Int, fieldChoiceID: Int?)
    /// 山札から引いた札が 2 枚マッチしたときの場札選択。
    case chooseDrawnField(fieldID: Int)
    /// こいこい（続行）。
    case koikoi
    /// 勝負（終了・得点）。
    case shobu
}

/// ラウンドの結果。
public struct RoundOutcome: Sendable, Hashable {
    /// 勝者。nil は流局（引き分け）。
    public let winner: Seat?
    /// 勝者が獲得した文数（流局は 0）。
    public let points: Int

    public init(winner: Seat?, points: Int) {
        self.winner = winner
        self.points = points
    }
}

/// ラウンド進行の現在フェーズ（= 次に必要な決定）。
public enum RoundPhase: Sendable, Hashable {
    /// `Seat` が手札を選ぶ。
    case selectHand(Seat)
    /// `Seat` が山札から引いた札の合わせ先（2 枚マッチ）を選ぶ。
    case selectDrawnField(Seat, drawn: Card, matches: [Card])
    /// `Seat` がこいこいか勝負かを選ぶ。
    case decideKoikoi(Seat, newYaku: [Yaku])
    /// ラウンド終了。
    case finished(RoundOutcome)
}

/// go-koikoi の UI メインループ相当のラウンド進行状態機械。
/// 「手札を出す → 山札を引いて合わせる → 新役チェック → こいこい/勝負」の
/// 順序・手札なし席のスキップ・流局処理を go-koikoi と同一に保つ。
public struct RoundSimulator: Sendable, Hashable {
    public private(set) var game: Game
    public private(set) var phase: RoundPhase

    /// 配札済み（`startRound()` 済み）のゲームからラウンド進行を開始する。
    public init(game: Game) {
        self.game = game
        if game.isRoundOver {
            phase = .finished(RoundOutcome(winner: nil, points: 0))
        } else if game.hand(for: game.currentTurn).isEmpty {
            // 手札のない席は飛ばす（go-koikoi: 空の手番は即ターン交代）
            self.game.currentTurn = game.currentTurn.other
            phase = .selectHand(game.currentTurn.other)
        } else {
            phase = .selectHand(game.currentTurn)
        }
    }

    /// 任意のフェーズから再開する（探索のルートを途中決定点に置く場合用）。
    public init(game: Game, phase: RoundPhase) {
        self.game = game
        self.phase = phase
    }

    /// 現在の決定を行う席。終了後は nil。
    public var seatToMove: Seat? {
        switch phase {
        case .selectHand(let seat), .selectDrawnField(let seat, _, _), .decideKoikoi(let seat, _):
            seat
        case .finished:
            nil
        }
    }

    public var isFinished: Bool {
        if case .finished = phase { return true }
        return false
    }

    public var outcome: RoundOutcome? {
        if case .finished(let outcome) = phase { return outcome }
        return nil
    }

    /// 現在フェーズで合法な手。
    public func legalMoves() -> [Move] {
        switch phase {
        case .selectHand(let seat):
            return game.hand(for: seat).flatMap { card -> [Move] in
                let matches = game.matchingFieldCards(for: card)
                if matches.count == 2 {
                    return matches.map { .playHand(handID: card.id, fieldChoiceID: $0.id) }
                }
                return [.playHand(handID: card.id, fieldChoiceID: nil)]
            }
        case .selectDrawnField(_, _, let matches):
            return matches.map { .chooseDrawnField(fieldID: $0.id) }
        case .decideKoikoi:
            return [.koikoi, .shobu]
        case .finished:
            return []
        }
    }

    /// 手を適用し、次の決定点（または終了）まで自動で進める。
    public mutating func apply(_ move: Move) {
        switch (phase, move) {
        case let (.selectHand(seat), .playHand(handID, fieldChoiceID)):
            guard let handCard = Card.card(id: handID) else {
                preconditionFailure("invalid hand card id \(handID)")
            }
            let fieldChoice = fieldChoiceID.flatMap(Card.card(id:))
            game.playCard(handCard, fieldChoice: fieldChoice, by: seat)
            drawStep(for: seat)
        case let (.selectDrawnField(seat, drawn, _), .chooseDrawnField(fieldID)):
            game.playDrawnCard(drawn, fieldChoice: Card.card(id: fieldID), by: seat)
            checkYaku(for: seat)
        case (.decideKoikoi(let seat, _), .koikoi):
            game.koikoiDeclared[seat] = true
            game.updatePreviousYaku(for: seat)
            endTurn(after: seat)
        case (.decideKoikoi(let seat, _), .shobu):
            finishRound(winner: seat)
        default:
            preconditionFailure("illegal move \(move) for phase \(phase)")
        }
    }

    // MARK: - 自動進行

    private mutating func drawStep(for seat: Seat) {
        guard let drawn = game.drawFromDeck() else {
            checkYaku(for: seat)
            return
        }
        let matches = game.matchingFieldCards(for: drawn)
        if matches.count == 2 {
            phase = .selectDrawnField(seat, drawn: drawn, matches: matches)
        } else {
            game.playDrawnCard(drawn, fieldChoice: nil, by: seat)
            checkYaku(for: seat)
        }
    }

    private mutating func checkYaku(for seat: Seat) {
        let newYaku = game.checkNewYaku(for: seat)
        if newYaku.isEmpty {
            endTurn(after: seat)
        } else if game.hand(for: seat).isEmpty {
            // 手札なし → こいこいできないので自動的に勝負
            finishRound(winner: seat)
        } else {
            phase = .decideKoikoi(seat, newYaku: newYaku)
        }
    }

    private mutating func endTurn(after seat: Seat) {
        if game.isRoundOver {
            // 流局: 無得点・親は変わらない
            phase = .finished(RoundOutcome(winner: nil, points: 0))
            return
        }
        let next = game.hand(for: seat.other).isEmpty ? seat : seat.other
        game.currentTurn = next
        phase = .selectHand(next)
    }

    private mutating func finishRound(winner seat: Seat) {
        let points = game.calcFinalScore(for: seat)
        game.scores[seat, default: 0] += points
        game.nextParent = seat
        phase = .finished(RoundOutcome(winner: seat, points: points))
    }
}

public extension RoundSimulator {
    /// 現在の決定点でのヒューリスティック方策の手（ISMCTS のロールアウトにも使う）。
    /// 終了後は nil。
    func heuristicMove(difficulty: Difficulty, rng: inout GameRandom) -> Move? {
        switch phase {
        case .selectHand(let seat):
            let choice = HeuristicOpponent.chooseHandCard(
                game: game, seat: seat, difficulty: difficulty, rng: &rng)
            return .playHand(handID: choice.handCard.id, fieldChoiceID: choice.fieldChoice?.id)
        case .selectDrawnField(_, _, let matches):
            let choice = HeuristicOpponent.chooseFieldCard(matches: matches) ?? matches[0]
            return .chooseDrawnField(fieldID: choice.id)
        case .decideKoikoi(let seat, _):
            // go-koikoi は新役ではなく現在の全役リストで判断する
            let yakus = YakuChecker.checkYaku(captured: game.captured(for: seat))
            let koikoi = HeuristicOpponent.decideKoikoi(
                game: game, seat: seat, yakus: yakus, difficulty: difficulty)
            return koikoi ? .koikoi : .shobu
        case .finished:
            return nil
        }
    }
}
