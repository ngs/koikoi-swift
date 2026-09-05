import Foundation
import Testing

@testable import KoikoiUI

/// 盤面幅に応じた札タイル幅のスケーリング規則。
@MainActor
@Suite struct GameViewLayoutTests {
    /// iPhone 相当の幅では従来どおり基準幅（64pt）で折り返す。
    @Test func narrowBoardKeepsBaseTileWidth() {
        #expect(GameView.tileWidth(forBoardWidth: 393) == GameView.cardTileWidth)
        #expect(GameView.tileWidth(forBoardWidth: 430) == GameView.cardTileWidth)
        // 未レイアウト（幅 0）でも基準幅にフォールバックする
        #expect(GameView.tileWidth(forBoardWidth: 0) == GameView.cardTileWidth)
    }

    /// iPad 13 インチ相当の幅では上限まで拡大する。
    @Test func wideBoardReachesMaximumTileWidth() {
        #expect(GameView.tileWidth(forBoardWidth: 1_024) == GameView.maxCardTileWidth)
        #expect(GameView.tileWidth(forBoardWidth: 1_366) == GameView.maxCardTileWidth)
    }

    /// compact 幅（iPhone 縦）では 8 枚 + 7 スペーシング + 左右パディングが 1 行に収まるよう縮む。
    @Test func compactBoardShrinksTilesToFitOneRow() {
        for width: CGFloat in [375, 393, 430] {
            let tile = GameView.tileWidth(forBoardWidth: width, compact: true)
            #expect(tile >= GameView.minCompactTileWidth)
            #expect(tile < GameView.cardTileWidth)
            #expect(GameView.boardWidth(forTile: tile, compact: true) <= width + 0.5)
        }
        #expect(GameView.tileWidth(forBoardWidth: 0, compact: true) == GameView.minCompactTileWidth)
    }

    /// 中間の幅では 8 枚 + 7 スペーシング + 左右パディングが 1 行に収まる。
    @Test func intermediateBoardFitsEightCardsInOneRow() {
        let width: CGFloat = 800
        let tile = GameView.tileWidth(forBoardWidth: width)
        #expect(tile > GameView.cardTileWidth)
        #expect(tile < GameView.maxCardTileWidth)
        #expect(tile * 8 + 8 * 7 + GameView.boardPadding * 2 <= width + 0.5)
    }
}
