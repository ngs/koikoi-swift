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

    /// Resources/Assets.xcassets/Cards に 48 枚全ての imageset がある
    /// （trace パイプラインと assetNames 表のズレを検出する）。
    /// SPM テストからアプリバンドルは見えないため、リポジトリ内の
    /// カタログソースを #filePath 起点で検証する。
    @Test func allCardImagesetsExistInCatalog() throws {
        let catalog = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KoikoiUITests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("Resources/Assets.xcassets/Cards")
        try #require(
            FileManager.default.fileExists(atPath: catalog.path),
            "catalog not found: \(catalog.path)")

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
