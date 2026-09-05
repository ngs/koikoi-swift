import Foundation
import KoikoiCore
import Testing

@testable import KoikoiUI

/// String Catalog（英語がソース言語・日本語訳あり）と Core の英語名の対応を検証する。
@MainActor
@Suite struct LocalizationTests {
    /// 検証対象のカタログ（リポジトリルートからの相対パス）。
    private static let catalogPaths = [
        "Sources/UI/Resources/Localizable.xcstrings",
        "Sources/UI/Resources/CardTypes.xcstrings",
        "Resources/Localizable.xcstrings"
    ]

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KoikoiUITests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
    }

    private struct Catalog {
        let path: String
        let sourceLanguage: String
        /// キー -> ロケール -> 訳文（state が translated のもののみ）。
        let strings: [String: [String: String]]
    }

    private func loadCatalog(_ relativePath: String) throws -> Catalog {
        let url = Self.repositoryRoot.appendingPathComponent(relativePath)
        try #require(
            FileManager.default.fileExists(atPath: url.path),
            "catalog not found: \(url.path)")
        let data = try Data(contentsOf: url)
        let json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "not a JSON object: \(relativePath)")
        let sourceLanguage = try #require(json["sourceLanguage"] as? String)
        let rawStrings = try #require(json["strings"] as? [String: Any])

        var strings: [String: [String: String]] = [:]
        for (key, value) in rawStrings {
            let entry = try #require(value as? [String: Any], "bad entry: \(key)")
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            var byLocale: [String: String] = [:]
            for (locale, unitBox) in localizations {
                guard let box = unitBox as? [String: Any],
                    let unit = box["stringUnit"] as? [String: Any],
                    let state = unit["state"] as? String, state == "translated",
                    let text = unit["value"] as? String, !text.isEmpty
                else { continue }
                byLocale[locale] = text
            }
            strings[key] = byLocale
        }
        return Catalog(path: relativePath, sourceLanguage: sourceLanguage, strings: strings)
    }

    /// 全カタログの sourceLanguage が en で、全キーに日本語訳がある。
    @Test func catalogsAreEnglishSourcedAndFullyTranslated() throws {
        for relativePath in Self.catalogPaths {
            let catalog = try loadCatalog(relativePath)
            #expect(catalog.sourceLanguage == "en", "\(relativePath) sourceLanguage")
            #expect(!catalog.strings.isEmpty, "\(relativePath) has no strings")
            for (key, byLocale) in catalog.strings {
                #expect(byLocale["ja"] != nil, "missing ja translation: \(relativePath) / \(key)")
            }
        }
    }

    /// Core の値に対する表示名が全て非空。
    @Test func coreValuesHaveLocalizedNames() {
        for kind in YakuKind.allCases {
            #expect(!kind.localizedName.isEmpty, "yaku: \(kind)")
        }
        for month in Month.allCases {
            #expect(!month.localizedMonthName.isEmpty, "month: \(month)")
            #expect(!month.localizedFlowerName.isEmpty, "flower: \(month)")
        }
        for type in CardType.allCases {
            #expect(!type.localizedName.isEmpty, "cardType: \(type)")
        }
        for level in Difficulty.allCases {
            #expect(!level.localizedLabel.isEmpty, "difficulty: \(level)")
        }
        for card in Card.all {
            #expect(!card.localizedName.isEmpty, "card: \(card.id)")
        }
    }

    /// Core の英語名がそのままカタログのキーとして載っている（漏れの検出）。
    @Test func coreEnglishNamesAreCatalogKeys() throws {
        let catalog = try loadCatalog("Sources/UI/Resources/Localizable.xcstrings")
        var expected: [String] = []
        expected += YakuKind.allCases.map(\.displayName)
        expected += Month.allCases.map(\.monthName)
        expected += Month.allCases.map(\.flowerName)
        expected += Difficulty.allCases.map(\.label)
        expected += Card.all.map(\.name)
        for key in expected {
            #expect(catalog.strings[key] != nil, "missing catalog key: \(key)")
        }

        // 札種は役名と英語が衝突するため別テーブル
        let cardTypes = try loadCatalog("Sources/UI/Resources/CardTypes.xcstrings")
        for type in CardType.allCases {
            #expect(cardTypes.strings[type.name] != nil, "missing card type key: \(type.name)")
        }
    }

    /// 札の日本語訳は 48 枚ぶん揃っていて重複しない（go-koikoi の札名と 1 対 1）。
    @Test func cardTranslationsAreCompleteAndDistinct() throws {
        let catalog = try loadCatalog("Sources/UI/Resources/Localizable.xcstrings")
        let translations = try Card.all.map { card in
            try #require(catalog.strings[card.name]?["ja"], "no ja for \(card.name)")
        }
        #expect(translations.count == 48)
        #expect(Set(translations).count == 48)
    }
}
