import Foundation
import KoikoiCore
import SwiftUI

// KoikoiCore は英語を正とし、日本語は String Catalog の翻訳値としてのみ持つ。
// ここでは Core の英語名（`displayName` / `monthName` / `flowerName` / `name` /
// `label`）をそのままキーにしてカタログを引く。
//
// 札種（`CardType.name`）だけは別テーブル `CardTypes` を使う。役の「Ribbons」
// （タン）と札種の「Ribbons」（短）は英語が同じで日本語が異なり、1 つの
// カタログでは同じキーに 2 つの訳を持てないため。

/// パッケージ内のカタログ引き（キーが実行時に決まるため LocalizationValue を組む）。
private func localized(_ key: String, table: String? = nil) -> String {
    String(
        localized: String.LocalizationValue(stringLiteral: key),
        table: table, bundle: .module)
}

public extension YakuKind {
    /// 役名（英語は `displayName`、日本語は 五光 / 四光 …）。
    var localizedName: String { localized(displayName) }
}

public extension Month {
    /// 月名（英語は January …、日本語は旧暦名 睦月 …）。
    var localizedMonthName: String { localized(monthName) }

    /// 花の名前（英語は Pine …、日本語は 松 …）。
    var localizedFlowerName: String { localized(flowerName) }
}

public extension CardType {
    /// 札種名（獲得札のグループ見出し）。役名と英語が衝突するため別テーブル。
    var localizedName: String { localized(name, table: Self.catalogTable) }

    /// 札種名のカタログテーブル名。
    static let catalogTable = "CardTypes"
}

public extension Difficulty {
    /// 難易度の表示名。
    var localizedLabel: String { localized(label) }
}

public extension Card {
    /// 札 1 枚の表示名（アクセシビリティラベル等）。
    var localizedName: String { localized(name) }
}

public extension Yaku {
    /// 「Five Brights (5 pts)」形式の 1 行表示。
    var localizedSummary: String {
        String(localized: "\(kind.localizedName) (\(points) pts)", bundle: .module)
    }
}

/// プラットフォーム間で共有する対局進行の文言。
public enum KoikoiText {
    public static func roundEndTitle(winner: Seat?) -> String {
        switch winner {
        case .player: String(localized: "You win the round!", bundle: .module)
        case .opponent: String(localized: "Opponent wins the round", bundle: .module)
        case nil: String(localized: "Draw", bundle: .module)
        }
    }

    public static func matchEndTitle(winner: Seat?) -> String {
        switch winner {
        case .player: String(localized: "You win the match!", bundle: .module)
        case .opponent: String(localized: "You lose the match…", bundle: .module)
        case nil: String(localized: "Match drawn", bundle: .module)
        }
    }

    /// 「3 pts」形式の獲得点。
    public static func points(_ value: Int) -> String {
        String(localized: "\(value) pts", bundle: .module)
    }

    /// 「You 12 pts – Opponent 7 pts」形式の最終スコア。
    public static func finalScore(player: Int, opponent: Int) -> String {
        String(localized: "You \(player) pts – Opponent \(opponent) pts", bundle: .module)
    }
}
