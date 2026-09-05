import Foundation
import Testing

@testable import KoikoiUI

/// デバッグ用の対局数上書き（起動引数 `-KoikoiDebugRounds <n>`）。
@MainActor
@Suite struct DebugRoundsOverrideTests {
    private func makeDefaults() throws -> UserDefaults {
        let name = "io.ngs.Koikoi.tests.\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: name))
    }

    @Test func overrideIsIgnoredWhenUnset() throws {
        let defaults = try makeDefaults()
        #expect(GameSessionView.resolvedRounds(12, defaults: defaults) == 12)
    }

    @Test func overrideReplacesSelectedRounds() throws {
        let defaults = try makeDefaults()
        defaults.set(1, forKey: GameSessionView.debugRoundsKey)
        #expect(GameSessionView.resolvedRounds(12, defaults: defaults) == 1)
        defaults.set(3, forKey: GameSessionView.debugRoundsKey)
        #expect(GameSessionView.resolvedRounds(12, defaults: defaults) == 3)
    }

    /// 0 や負値は無視して選択された対局数を使う。
    @Test func nonPositiveOverrideIsIgnored() throws {
        let defaults = try makeDefaults()
        defaults.set(0, forKey: GameSessionView.debugRoundsKey)
        #expect(GameSessionView.resolvedRounds(6, defaults: defaults) == 6)
        defaults.set(-1, forKey: GameSessionView.debugRoundsKey)
        #expect(GameSessionView.resolvedRounds(6, defaults: defaults) == 6)
    }
}
