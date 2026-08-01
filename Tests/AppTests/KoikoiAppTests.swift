import KoikoiCore
import KoikoiUI
import XCTest

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

final class KoikoiAppTests: XCTestCase {
    func testAppTargetLinks() {
        XCTAssertTrue(true)
    }

    /// アプリカタログ（Assets.xcassets/Cards）に 48 枚全ての札画像が
    /// コンパイルされている。
    func testAllCardAssetsCompiledIntoApp() {
        for card in Card.all {
            #if canImport(UIKit)
            XCTAssertNotNil(UIImage(named: card.assetName), "missing: \(card.assetName)")
            #elseif canImport(AppKit)
            XCTAssertNotNil(NSImage(named: card.assetName), "missing: \(card.assetName)")
            #endif
        }
    }
}
