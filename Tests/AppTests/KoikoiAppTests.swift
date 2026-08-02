import KoikoiCore
import KoikoiUI
import SwiftUI
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

    /// 対局画面が描画でき、スナップショット PNG を書き出せる（描画スモーク）。
    /// 出力: /tmp/koikoi_snapshots/*.png — 目視確認にも使う。
    @MainActor
    func testRenderGameViewSnapshot() throws {
        let model = GameViewModel(
            rounds: 3, difficulty: .normal, seed: 42, aiStepDelay: .seconds(60))
        // dropTargetsEnabled: ImageRenderer はドロップ受けを禁止マークの
        // プレースホルダとして描くため、スナップショットでは外す
        let view = GameView(model: model, dropTargetsEnabled: false)
            .frame(width: 640, height: 840)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        #if canImport(AppKit)
        let image = try XCTUnwrap(renderer.nsImage, "GameView failed to render")
        let dir = URL(fileURLWithPath: "/tmp/koikoi_snapshots")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let png = try XCTUnwrap(
            NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
        try png.write(to: dir.appendingPathComponent("game_view.png"))
        #else
        XCTAssertNotNil(renderer.uiImage, "GameView failed to render")
        #endif
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
