import Testing

@testable import KoikoiAI
@testable import KoikoiCore

@Suite struct DeterminizerTests {
    private func dealtSimulator(seed: UInt64) -> RoundSimulator {
        var game = Game(rounds: 1, rng: GameRandom(seed: seed))
        game.startRound()
        return RoundSimulator(game: game)
    }

    /// 見えている情報（自分の手札・場・獲得札・枚数）は決定化で変わらない。
    @Test func preservesVisibleInformation() {
        let sim = dealtSimulator(seed: 10)
        var rng = GameRandom(seed: 1)
        let det = Determinizer.determinize(sim, for: .opponent, rng: &rng)

        #expect(det.game.hand(for: .opponent) == sim.game.hand(for: .opponent))
        #expect(det.game.field == sim.game.field)
        #expect(det.game.captured(for: .player) == sim.game.captured(for: .player))
        #expect(det.game.captured(for: .opponent) == sim.game.captured(for: .opponent))
        #expect(det.game.hand(for: .player).count == sim.game.hand(for: .player).count)
        #expect(det.game.deck.count == sim.game.deck.count)
        #expect(det.phase == sim.phase)
    }

    /// 未見札（相手手札 + 山札）の集合は決定化の前後で一致する。
    @Test func hiddenPoolIsPermutation() {
        let sim = dealtSimulator(seed: 11)
        var rng = GameRandom(seed: 2)
        let det = Determinizer.determinize(sim, for: .opponent, rng: &rng)

        let before = Set((sim.game.hand(for: .player) + sim.game.deck).map(\.id))
        let after = Set((det.game.hand(for: .player) + det.game.deck).map(\.id))
        #expect(before == after)
    }

    /// 同じシードなら同じ決定化になる（探索の再現性）。
    @Test func deterministicWithSameSeed() {
        let sim = dealtSimulator(seed: 12)
        var rng1 = GameRandom(seed: 3)
        var rng2 = GameRandom(seed: 3)
        let det1 = Determinizer.determinize(sim, for: .opponent, rng: &rng1)
        let det2 = Determinizer.determinize(sim, for: .opponent, rng: &rng2)
        #expect(det1 == det2)
    }

    /// 異なるシードでは（ほぼ確実に）異なる隠れ状態がサンプルされる。
    @Test func differentSeedsSampleDifferentStates() {
        let sim = dealtSimulator(seed: 13)
        var sampled: Set<[Int]> = []
        for seed: UInt64 in 0..<8 {
            var rng = GameRandom(seed: seed)
            let det = Determinizer.determinize(sim, for: .opponent, rng: &rng)
            sampled.insert(det.game.hand(for: .player).map(\.id))
        }
        #expect(sampled.count > 1)
    }
}
