import Foundation
import SwiftUI
import Testing

@testable import KoikoiUI

/// 配色テーマ（Colors.xcassets の名前空間と `KoikoiTheme` の対応）。
///
/// SwiftPM は xcassets をコンパイルせずそのままバンドルへコピーするため、
/// `swift test` では `NSColor(named:bundle:)` で解決できない。ここではカタログの
/// 中身を直接読んで名前の欠けを検出し、実際の解決は Tests/AppTests
/// （アプリのビルドで Assets.car が作られる）で確認する。
@Suite struct ThemeTests {
    /// パレットが引く 6 色。
    static let colorNames = ["Table", "CardBack", "CardBackEdge", "Highlight", "Ink", "Badge"]

    /// 全テーマ × 全色のカラーセットがカタログにある。
    @Test func everyThemeHasAllColorSets() throws {
        let catalog = try #require(
            Bundle.module.url(forResource: "Colors", withExtension: "xcassets"),
            "Colors.xcassets is not in the resource bundle")
        for theme in KoikoiTheme.allCases {
            // system は OS 標準色を使うのでカタログを持たない
            guard let assetFolder = theme.assetFolder else { continue }
            let folder = catalog.appending(path: assetFolder)
            // フォルダは名前空間を提供する（= 色名が "Felt/Table" のように解決される）
            let contents = try Data(contentsOf: folder.appending(path: "Contents.json"))
            let json = try JSONSerialization.jsonObject(with: contents) as? [String: Any]
            let properties = json?["properties"] as? [String: Any]
            #expect(
                properties?["provides-namespace"] as? Bool == true,
                "\(assetFolder) does not provide a namespace")
            for name in Self.colorNames {
                let colorSet = folder.appending(path: "\(name).colorset/Contents.json")
                #expect(
                    FileManager.default.fileExists(atPath: colorSet.path),
                    "missing color: \(assetFolder)/\(name)")
            }
        }
    }

    /// 保存値（`@AppStorage`）との往復ができる。
    @Test func rawValuesRoundTrip() {
        #expect(KoikoiTheme.allCases.count == 4)
        // ピッカーの並びは System が先頭
        #expect(KoikoiTheme.allCases.first == .system)
        for theme in KoikoiTheme.allCases {
            #expect(KoikoiTheme(rawValue: theme.rawValue) == theme)
            #expect(!theme.localizedName.isEmpty)
        }
        #expect(KoikoiTheme.system.assetFolder == nil)
        #expect(KoikoiTheme(rawValue: "no-such-theme") == nil)
        #expect(KoikoiTheme.storageKey == "koikoi.theme")
    }

    /// system テーマはカタログを引かずに組み立てられる。
    @Test func systemPaletteBuildsWithoutTheCatalog() {
        let palette = KoikoiPalette(theme: .system)
        #expect(palette.highlight == Color.accentColor)
        #expect(palette.ink == Color.primary)
        #expect(palette.badgeText == Color.white)
    }
}
