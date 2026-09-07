import Foundation
import KoikoiCore
import Testing

@testable import KoikoiUI

/// 起動引数によるデバッグ用の上書き（`-KoikoiDebugRounds` / `-KoikoiDebugFixture` /
/// `-KoikoiDebugTheme`）。
@MainActor
@Suite struct DebugLaunchOptionsTests {
    private func makeDefaults() throws -> UserDefaults {
        let name = "io.ngs.Koikoi.tests.\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: name))
    }

    private func makeFile(_ data: Data) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("fixture-\(UUID().uuidString).koikoi")
        try data.write(to: url)
        return url
    }

    // MARK: - 対局数

    @Test func overrideIsIgnoredWhenUnset() throws {
        let defaults = try makeDefaults()
        #expect(KoikoiDebugLaunch.rounds(12, defaults: defaults) == 12)
    }

    @Test func overrideReplacesSelectedRounds() throws {
        let defaults = try makeDefaults()
        defaults.set(1, forKey: KoikoiDebugLaunch.roundsKey)
        #expect(KoikoiDebugLaunch.rounds(12, defaults: defaults) == 1)
        defaults.set(3, forKey: KoikoiDebugLaunch.roundsKey)
        #expect(KoikoiDebugLaunch.rounds(12, defaults: defaults) == 3)
    }

    /// 0 や負値は無視して選択された対局数を使う。
    @Test func nonPositiveOverrideIsIgnored() throws {
        let defaults = try makeDefaults()
        defaults.set(0, forKey: KoikoiDebugLaunch.roundsKey)
        #expect(KoikoiDebugLaunch.rounds(6, defaults: defaults) == 6)
        defaults.set(-1, forKey: KoikoiDebugLaunch.roundsKey)
        #expect(KoikoiDebugLaunch.rounds(6, defaults: defaults) == 6)
    }

    // MARK: - 局面の差し替え

    @Test func fixtureIsNilWhenUnset() throws {
        let defaults = try makeDefaults()
        #expect(KoikoiDebugLaunch.fixture(defaults: defaults) == nil)
    }

    /// 指定したファイルの対局記録がそのまま返る。
    @Test func fixtureLoadsRecordFromPath() throws {
        let defaults = try makeDefaults()
        let record = GameRecord(
            rounds: 3, difficulty: .hard, seed: 99,
            moves: [.playHand(handID: 4, fieldChoiceID: nil), .koikoi])
        let url = try makeFile(KoikoiGameDocument.encode(record))
        defer { try? FileManager.default.removeItem(at: url) }
        defaults.set(url.path, forKey: KoikoiDebugLaunch.fixtureKey)
        #expect(KoikoiDebugLaunch.fixture(defaults: defaults) == record)
    }

    /// 空パス・存在しないファイル・壊れたファイルは通常の復元にフォールバックする。
    @Test func fixtureIsNilForUnusablePaths() throws {
        let defaults = try makeDefaults()
        defaults.set("", forKey: KoikoiDebugLaunch.fixtureKey)
        #expect(KoikoiDebugLaunch.fixture(defaults: defaults) == nil)

        defaults.set("/nonexistent/state.koikoi", forKey: KoikoiDebugLaunch.fixtureKey)
        #expect(KoikoiDebugLaunch.fixture(defaults: defaults) == nil)

        let broken = try makeFile(Data("not json".utf8))
        defer { try? FileManager.default.removeItem(at: broken) }
        defaults.set(broken.path, forKey: KoikoiDebugLaunch.fixtureKey)
        #expect(KoikoiDebugLaunch.fixture(defaults: defaults) == nil)
    }

    // MARK: - 配色

    @Test func themeFallsBackToStoredValue() throws {
        let defaults = try makeDefaults()
        #expect(KoikoiDebugLaunch.theme(KoikoiTheme.tatami.rawValue, defaults: defaults) == .tatami)
        // 未知の名前は既定の緑羅紗
        #expect(KoikoiDebugLaunch.theme("nope", defaults: defaults) == .felt)
    }

    @Test func themeOverrideWins() throws {
        let defaults = try makeDefaults()
        defaults.set(KoikoiTheme.night.rawValue, forKey: KoikoiDebugLaunch.themeKey)
        #expect(KoikoiDebugLaunch.theme(KoikoiTheme.felt.rawValue, defaults: defaults) == .night)
        // 未知の名前の上書きは無視する
        defaults.set("nope", forKey: KoikoiDebugLaunch.themeKey)
        #expect(KoikoiDebugLaunch.theme(KoikoiTheme.felt.rawValue, defaults: defaults) == .felt)
    }
}
