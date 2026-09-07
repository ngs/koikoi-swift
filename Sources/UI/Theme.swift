import SwiftUI

/// 盤面の配色。`system` 以外の色は `Resources/Colors.xcassets` にあり、
/// テーマごとの名前空間（Felt / Tatami / Night）から引く。
public enum KoikoiTheme: String, CaseIterable, Identifiable, Sendable {
    /// OS 標準色（ライト / ダークとアクセントカラーに追従する）。
    case system
    /// 緑羅紗（従来の見た目）。
    case felt
    /// 畳（藁色の卓に黒漆の裏札）。
    case tatami
    /// 夜（藍の卓に金の強調色）。
    case night

    public var id: String { rawValue }

    /// Colors.xcassets 内のフォルダ名（名前空間）。`system` はカタログを使わない。
    public var assetFolder: String? {
        switch self {
        case .system: return nil
        case .felt: return "Felt"
        case .tatami: return "Tatami"
        case .night: return "Night"
        }
    }

    /// 設定画面に出す表示名。
    public var localizedName: String {
        switch self {
        case .system: return String(localized: "System", bundle: .module)
        case .felt: return String(localized: "Felt", bundle: .module)
        case .tatami: return String(localized: "Tatami", bundle: .module)
        case .night: return String(localized: "Night", bundle: .module)
        }
    }

    /// 選択中のテーマの保存先（`@AppStorage`。既定は緑羅紗）。
    public static let storageKey = "koikoi.theme"
}

/// テーマ以外の見た目の設定（背景の透過）。
public enum KoikoiAppearance {
    /// 背景を透過するかの保存先（`@AppStorage`）。
    public static let translucencyStorageKey = "koikoi.translucentWindow"

    /// 既定値。visionOS はガラスのウィンドウが標準なので有効、他は無効。
    public static let defaultTranslucency: Bool = {
        #if os(visionOS)
        return true
        #else
        return false
        #endif
    }()

    /// 透過を選べる環境か（ウィンドウの背後に何かがある macOS と visionOS だけ）。
    public static var isAvailable: Bool {
        #if os(macOS) || os(visionOS)
        return true
        #else
        return false
        #endif
    }

    /// 透過時にテーマ色をマテリアルへ薄く重ねる濃さ（system テーマは重ねない）。
    public static let tintOpacity: Double = 0.35
}

/// 1 テーマ分の色。UI の色リテラルは全てここを経由する。
public struct KoikoiPalette: Sendable {
    /// 卓（盤面の背景）。
    public let table: Color
    /// 札の裏面と、その縁取り。
    public let cardBack: Color
    public let cardBackEdge: Color
    /// 強調（選択枠・ステータス文言・マッチ枚数バッジ）。
    public let highlight: Color
    /// 卓の上に乗る文字と罫線。
    public let ink: Color
    /// 役バッジの地色。
    public let badge: Color
    /// 強調バッジ（マッチ枚数）に乗せる文字の色。
    public let badgeText: Color
    /// OS 標準色のテーマか（macOS ではウィンドウを半透明にする判断に使う）。
    public let usesSystemColors: Bool

    public init(theme: KoikoiTheme) {
        guard let folder = theme.assetFolder else {
            // OS 標準色。ライト / ダークとアクセントカラーに追従する
            #if canImport(UIKit)
            table = Color(uiColor: .systemBackground)
            cardBack = Color(uiColor: .systemGray)
            badge = Color(uiColor: .systemRed)
            #else
            table = Color(nsColor: .windowBackgroundColor)
            cardBack = Color(nsColor: .systemGray)
            badge = Color(nsColor: .systemRed)
            #endif
            cardBackEdge = Color.primary.opacity(0.4)
            highlight = Color.accentColor
            ink = Color.primary
            // アクセントカラーは濃いこともあるため、その上の文字は白にする
            badgeText = .white
            usesSystemColors = true
            return
        }
        table = Color("\(folder)/Table", bundle: .module)
        cardBack = Color("\(folder)/CardBack", bundle: .module)
        cardBackEdge = Color("\(folder)/CardBackEdge", bundle: .module)
        highlight = Color("\(folder)/Highlight", bundle: .module)
        ink = Color("\(folder)/Ink", bundle: .module)
        badge = Color("\(folder)/Badge", bundle: .module)
        // カタログの強調色はどれも明るいので、その上の文字は黒で読める
        badgeText = .black
        usesSystemColors = false
    }
}

private struct KoikoiPaletteKey: EnvironmentKey {
    static let defaultValue = KoikoiPalette(theme: .felt)
}

public extension EnvironmentValues {
    /// 盤面の配色（既定は緑羅紗）。
    var koikoiPalette: KoikoiPalette {
        get { self[KoikoiPaletteKey.self] }
        set { self[KoikoiPaletteKey.self] = newValue }
    }
}

public extension View {
    /// このビュー以下の配色をテーマで切り替える。
    func koikoiTheme(_ theme: KoikoiTheme) -> some View {
        environment(\.koikoiPalette, KoikoiPalette(theme: theme))
    }
}

public extension Bundle {
    /// KoikoiUI のリソースバンドル（色と文言のカタログ）。
    /// アプリ側のテストからアセットの解決を確認するために公開する。
    static let koikoiUI = Bundle.module
}
