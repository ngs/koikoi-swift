import Foundation
import KoikoiCore
import Testing

@testable import KoikoiUI

@Suite struct CardAssetsTests {
    /// 48 枚全てにアセット名があり、`{id:02d}_` 形式で ID と一致する。
    @Test func assetNamesMatchCardIDs() {
        var seen: Set<String> = []
        for card in Card.all {
            let name = card.assetName
            #expect(name.hasPrefix(String(format: "%02d_", card.id)), "id \(card.id): \(name)")
            seen.insert(name)
        }
        #expect(seen.count == 48)
    }

    /// 絵柄の submodule に 48 枚全ての imageset がある
    /// （trace パイプラインと assetNames 表のズレを検出する）。
    /// SPM テストからアプリバンドルは見えないため、リポジトリ内の
    /// カタログソースを #filePath 起点で検証する。
    /// 札の絵柄は MIT 適用外の private submodule にあるため、未取得の環境
    /// （submodule への権限がない clone）ではこの検証を飛ばす。CI は
    /// submodules: recursive で取得するので、そこでは必ず実行される。
    @Test func allCardImagesetsExistInCatalog() {
        let catalog = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KoikoiUITests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent(
                "Assets/koikoi-swift-assets/KoikoiArtwork.xcassets/Cards")
        guard FileManager.default.fileExists(atPath: catalog.path) else {
            return
        }

        for card in Card.all {
            let svg = catalog
                .appendingPathComponent("\(card.assetName).imageset")
                .appendingPathComponent("\(card.assetName).svg")
            #expect(
                FileManager.default.fileExists(atPath: svg.path),
                "missing asset source: \(card.assetName)")
        }
    }
}
