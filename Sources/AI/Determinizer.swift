import Foundation
import KoikoiCore

/// 情報集合の決定化。
/// `seat` から見えない札（相手の手札と山札の中身）をシャッフルし直し、
/// 観測（枚数・公開札）と矛盾しない完全情報状態を 1 つサンプルする。
enum Determinizer {
    static func determinize(
        _ simulator: RoundSimulator, for seat: Seat, rng: inout GameRandom
    ) -> RoundSimulator {
        var game = simulator.game
        let opponent = seat.other

        var unseen = game.hand(for: opponent) + game.deck
        unseen.shuffle(using: &rng)

        let handCount = game.hand(for: opponent).count
        game.setHand(Array(unseen.prefix(handCount)), for: opponent)
        game.deck = Array(unseen.dropFirst(handCount))

        return RoundSimulator(game: game, phase: simulator.phase)
    }
}
