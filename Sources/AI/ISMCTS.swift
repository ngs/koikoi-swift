import Foundation
import KoikoiCore

/// ISMCTS 探索のパラメータ。
public struct ISMCTSConfiguration: Sendable, Hashable {
    /// 反復回数（1 決定あたりの決定化 + シミュレーション数）。
    public var iterations: Int
    /// UCB1 の探索定数。報酬が [0, 1] なので 0.7 前後が目安。
    public var exploration: Double
    /// ロールアウト（プレイアウト）に使うヒューリスティック難易度。
    public var rolloutDifficulty: Difficulty

    public init(
        iterations: Int = 800,
        exploration: Double = 0.7,
        rolloutDifficulty: Difficulty = .normal
    ) {
        self.iterations = iterations
        self.exploration = exploration
        self.rolloutDifficulty = rolloutDifficulty
    }
}

/// Determinized single-observer ISMCTS。
/// 反復のたびに未見情報（相手手札・山札）を決定化して単一の木を成長させ、
/// UCB1（availability count 付き）で選択、`HeuristicOpponent` でロールアウトする。
public struct ISMCTSEngine: Sendable {
    public var configuration: ISMCTSConfiguration

    public init(configuration: ISMCTSConfiguration = ISMCTSConfiguration()) {
        self.configuration = configuration
    }

    /// 現在の決定点で最善手を探索する。決定点でなければ nil。
    public func chooseMove(
        in simulator: RoundSimulator, for seat: Seat, rng: inout GameRandom
    ) -> Move? {
        guard simulator.seatToMove == seat else { return nil }
        let legal = simulator.legalMoves()
        guard let first = legal.first else { return nil }
        if legal.count == 1 { return first }

        let root = Node(move: nil)
        for _ in 0..<configuration.iterations {
            var state = Determinizer.determinize(simulator, for: seat, rng: &rng)
            iterate(root: root, state: &state, perspective: seat, rng: &rng)
        }

        let best = root.children.values.max { $0.visits < $1.visits }
        return best?.move ?? first
    }

    // MARK: - 探索本体

    private final class Node {
        let move: Move?
        var children: [Move: Node] = [:]
        var visits = 0
        /// この手が合法だった選択機会の数（ISMCTS の UCB1 分子に使う）。
        var availability = 0
        /// `perspective` 視点の報酬合計。
        var totalReward = 0.0

        init(move: Move?) {
            self.move = move
        }
    }

    private func iterate(
        root: Node, state: inout RoundSimulator, perspective: Seat, rng: inout GameRandom
    ) {
        var node = root
        var path = [root]

        // 選択と展開
        while !state.isFinished {
            let legal = state.legalMoves()
            let seatToMove = state.seatToMove ?? perspective
            let untried = legal.filter { node.children[$0] == nil }

            if let expanded = pick(untried, using: &rng) {
                let child = Node(move: expanded)
                child.availability = 1
                node.children[expanded] = child
                state.apply(expanded)
                path.append(child)
                break
            }

            let candidates = legal.compactMap { node.children[$0] }
            for candidate in candidates {
                candidate.availability += 1
            }
            guard let selected = candidates.max(by: {
                ucb($0, mover: seatToMove, perspective: perspective)
                    < ucb($1, mover: seatToMove, perspective: perspective)
            }), let selectedMove = selected.move else { break }
            state.apply(selectedMove)
            path.append(selected)
            node = selected
        }

        // ロールアウト
        var rolloutRng = rng
        while !state.isFinished {
            guard let move = state.heuristicMove(
                difficulty: configuration.rolloutDifficulty, rng: &rolloutRng) else { break }
            state.apply(move)
        }
        rng = rolloutRng

        // 逆伝播
        let value = reward(for: state.outcome, perspective: perspective)
        for visited in path {
            visited.visits += 1
            visited.totalReward += value
        }
    }

    private func ucb(_ node: Node, mover: Seat, perspective: Seat) -> Double {
        guard node.visits > 0 else { return .infinity }
        let mean = node.totalReward / Double(node.visits)
        // 木は perspective 視点の報酬を持つので、相手の決定点では反転して評価する
        let exploitation = mover == perspective ? mean : 1.0 - mean
        let exploration = configuration.exploration
            * (log(Double(max(node.availability, 1))) / Double(node.visits)).squareRoot()
        return exploitation + exploration
    }

    /// ラウンド結果を [0, 1] の報酬へ写す（0.5 が引き分け・文数で振幅）。
    private func reward(for outcome: RoundOutcome?, perspective: Seat) -> Double {
        guard let outcome, let winner = outcome.winner else { return 0.5 }
        let magnitude = min(Double(outcome.points) / 12.0, 1.0)
        return winner == perspective ? 0.5 + 0.5 * magnitude : 0.5 - 0.5 * magnitude
    }

    private func pick(_ moves: [Move], using rng: inout GameRandom) -> Move? {
        guard !moves.isEmpty else { return nil }
        return moves[Int.random(in: 0..<moves.count, using: &rng)]
    }
}

/// `HeuristicOpponent` と同じ形で使える ISMCTS 打ち手（`Difficulty.search` の実体)。
public enum SearchOpponent {
    /// 出す手札（と 2 枚マッチ時の場札）を探索で選ぶ。
    public static func chooseHandCard(
        game: Game, seat: Seat,
        engine: ISMCTSEngine = ISMCTSEngine(),
        rng: inout GameRandom
    ) -> (handCard: Card, fieldChoice: Card?) {
        let simulator = RoundSimulator(game: game, phase: .selectHand(seat))
        if case .playHand(let handID, let fieldChoiceID)? =
            engine.chooseMove(in: simulator, for: seat, rng: &rng),
            let handCard = Card.card(id: handID) {
            return (handCard, fieldChoiceID.flatMap(Card.card(id:)))
        }
        return HeuristicOpponent.chooseHandCard(
            game: game, seat: seat, difficulty: .hard, rng: &rng)
    }

    /// 山札から引いた札の合わせ先（2 枚マッチ）を探索で選ぶ。
    public static func chooseDrawnFieldCard(
        game: Game, drawn: Card, matches: [Card], seat: Seat,
        engine: ISMCTSEngine = ISMCTSEngine(),
        rng: inout GameRandom
    ) -> Card? {
        guard matches.count == 2 else {
            return HeuristicOpponent.chooseFieldCard(matches: matches)
        }
        let simulator = RoundSimulator(
            game: game, phase: .selectDrawnField(seat, drawn: drawn, matches: matches))
        if case .chooseDrawnField(let fieldID)? =
            engine.chooseMove(in: simulator, for: seat, rng: &rng) {
            return Card.card(id: fieldID)
        }
        return HeuristicOpponent.chooseFieldCard(matches: matches)
    }

    /// こいこいするかどうかを探索で決める。
    public static func decideKoikoi(
        game: Game, seat: Seat, newYaku: [Yaku],
        engine: ISMCTSEngine = ISMCTSEngine(),
        rng: inout GameRandom
    ) -> Bool {
        let simulator = RoundSimulator(game: game, phase: .decideKoikoi(seat, newYaku: newYaku))
        let move = engine.chooseMove(in: simulator, for: seat, rng: &rng)
        return move == .koikoi
    }
}
