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
        try renderGameView(width: 640, height: 840, filename: "game_view.png")
    }

    /// iPad 13 インチ相当の幅で描画し、札が拡大されることを目視確認するための
    /// スナップショット（出力: /tmp/koikoi_snapshots/game_view_ipad.png）。
    @MainActor
    func testRenderGameViewSnapshotIPad() throws {
        try renderGameView(width: 1_024, height: 1_366, filename: "game_view_ipad.png")
    }

    /// 横向き iPhone（vertical size class = compact）の三列レイアウトを描画する。
    /// 出力: /tmp/koikoi_snapshots/game_view_landscape.png
    @MainActor
    func testRenderGameViewLandscapeSnapshot() throws {
        let model = GameViewModel(
            rounds: 3, difficulty: .normal, seed: 42, aiStepDelay: .seconds(60))
        try render(
            model: model, width: 874, height: 402,
            filename: "game_view_landscape.png", landscapePhone: true)
    }

    /// 1 局対局を最後まで進め、ラウンド終了ダイアログと対局終了ダイアログを描画する。
    /// 出力: /tmp/koikoi_snapshots/game_view_round_end.png / game_view_match_end.png
    /// 対局終了時に onMatchEnd が呼ばれる（= 保存を捨てる）ことも併せて確認する。
    @MainActor
    func testRenderMatchEndSnapshot() async throws {
        let model = GameViewModel(
            rounds: 1, difficulty: .normal, seed: 42, aiStepDelay: .zero,
            captureAnimationsEnabled: false)
        var matchEnds = 0
        model.onMatchEnd = { _ in matchEnds += 1 }

        var renderedRoundEnd = false
        var steps = 0
        while steps < 300 {
            steps += 1
            // 相手の手番が終わるのを待つ
            var waited = 0
            while model.prompt == .opponentTurn, waited < 400 {
                waited += 1
                try await Task.sleep(for: .milliseconds(10))
            }
            switch model.prompt {
            case .selectHand:
                let hand = model.game.hand(for: .player)
                let card = try XCTUnwrap(hand.first, "empty hand")
                model.tapHandCard(card)
            case .selectField(let candidates):
                model.tapFieldCard(try XCTUnwrap(candidates.first))
            case .decideKoikoi:
                model.decide(koikoi: false)
            case .opponentTurn:
                continue
            case .roundEnd:
                if !renderedRoundEnd {
                    renderedRoundEnd = true
                    try render(model: model, filename: "game_view_round_end.png")
                }
                XCTAssertEqual(matchEnds, 0, "onMatchEnd should not fire before the match ends")
                model.proceedAfterRound()
            case .matchEnd:
                XCTAssertEqual(matchEnds, 1, "onMatchEnd should fire exactly once")
                try render(model: model, filename: "game_view_match_end.png")
                XCTAssertTrue(renderedRoundEnd, "round end dialog was never shown")
                return
            }
        }
        XCTFail("match did not finish: \(model.prompt)")
    }

    @MainActor
    private func renderGameView(width: CGFloat, height: CGFloat, filename: String) throws {
        let model = GameViewModel(
            rounds: 3, difficulty: .normal, seed: 42, aiStepDelay: .seconds(60))
        // dropTargetsEnabled: ImageRenderer はドロップ受けを禁止マークの
        // プレースホルダとして描くため、スナップショットでは外す
        try render(model: model, width: width, height: height, filename: filename)
    }

    @MainActor
    private func render(
        model: GameViewModel,
        width: CGFloat = 640,
        height: CGFloat = 840,
        filename: String,
        landscapePhone: Bool = false
    ) throws {
        // dropTargetsEnabled: ImageRenderer はドロップ受けを禁止マークの
        // プレースホルダとして描くため、スナップショットでは外す
        let board = GameView(model: model, dropTargetsEnabled: false, onExit: {})
            .frame(width: width, height: height)
        #if canImport(UIKit)
        // 横向き iPhone のレイアウトは vertical size class で切り替わる
        let view = AnyView(
            board.environment(\.verticalSizeClass, landscapePhone ? .compact : nil))
        #else
        let view = AnyView(board)
        #endif
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        let dir = URL(fileURLWithPath: "/tmp/koikoi_snapshots")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        #if canImport(UIKit)
        let image = try XCTUnwrap(renderer.uiImage, "GameView failed to render")
        let png = try XCTUnwrap(image.pngData())
        #elseif canImport(AppKit)
        let image = try XCTUnwrap(renderer.nsImage, "GameView failed to render")
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let png = try XCTUnwrap(
            NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
        #endif
        try png.write(to: dir.appendingPathComponent(filename))
    }

    /// KoikoiUI の Colors.xcassets が実際にコンパイルされ、全テーマ × 全色が引ける。
    /// （SwiftPM の `swift test` はカタログを未コンパイルのままコピーするため、
    /// アセットの解決はアプリのビルドを伴うこのターゲットで確認する）
    func testEveryThemeColorResolves() {
        let names = ["Table", "CardBack", "CardBackEdge", "Highlight", "Ink", "Badge"]
        for theme in KoikoiTheme.allCases {
            // system は OS 標準色なのでカタログを持たない
            guard let folder = theme.assetFolder else { continue }
            for name in names {
                let assetName = "\(folder)/\(name)"
                #if canImport(UIKit)
                XCTAssertNotNil(
                    UIColor(named: assetName, in: .koikoiUI, compatibleWith: nil),
                    "missing color: \(assetName)")
                #elseif canImport(AppKit)
                XCTAssertNotNil(
                    NSColor(named: NSColor.Name(assetName), bundle: .koikoiUI),
                    "missing color: \(assetName)")
                #endif
            }
        }
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
