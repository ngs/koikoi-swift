import Foundation

/// 起動引数によるデバッグ用の上書き（DEBUG ビルドでのみ効く）。
///
/// スクリーンショットの撮影や終了フローの確認のように、決まった局面・配色で
/// アプリを立ち上げたいときに使う。引数は `NSArgumentDomain` に入るだけなので、
/// ユーザーが選んだ設定や保存済みの対局は書き換えない。
///
/// ```sh
/// xcrun simctl launch <udid> io.ngs.Koikoi \
///     -KoikoiDebugFixture /path/to/state.koikoi -KoikoiDebugTheme night
/// ```
public enum KoikoiDebugLaunch {
    /// 対局数の上書き（`-KoikoiDebugRounds <n>`）。
    public static let roundsKey = "KoikoiDebugRounds"
    /// 復元する対局記録のパス（`-KoikoiDebugFixture <path>`）。
    public static let fixtureKey = "KoikoiDebugFixture"
    /// 配色の上書き（`-KoikoiDebugTheme <felt|tatami|night|system>`）。
    public static let themeKey = "KoikoiDebugTheme"

    /// 対局数（上書きが無い / 0 以下なら選択された値のまま）。
    public static func rounds(_ rounds: Int, defaults: UserDefaults = .standard) -> Int {
        #if DEBUG
        let override = defaults.integer(forKey: roundsKey)
        if override >= 1 { return override }
        #endif
        return rounds
    }

    /// 保存済みの対局の代わりに復元する記録
    /// （引数が無い・ファイルが読めない・壊れている場合は nil）。
    public static func fixture(defaults: UserDefaults = .standard) -> GameRecord? {
        #if DEBUG
        guard let path = defaults.string(forKey: fixtureKey), !path.isEmpty,
            let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let record = try? KoikoiGameDocument.decode(data)
        else { return nil }
        return record
        #else
        return nil
        #endif
    }

    /// 配色（上書きが無い / 未知の名前なら保存された値のまま）。
    public static func theme(_ raw: String, defaults: UserDefaults = .standard) -> KoikoiTheme {
        #if DEBUG
        if let name = defaults.string(forKey: themeKey),
            let override = KoikoiTheme(rawValue: name) {
            return override
        }
        #endif
        return KoikoiTheme(rawValue: raw) ?? .felt
    }
}
