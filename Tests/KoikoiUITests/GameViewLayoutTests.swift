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

    /// 横向き iPhone: 中央幅と高さの小さい方で札幅が決まる。
    @Test func landscapePhoneTileFitsBothWidthAndHeight() {
        // iPhone 17 Pro の画面（874×402）と、セーフエリアを引いた実測サイズ（756×381）
        let full = GameView.landscapeTileWidth(forBoardSize: CGSize(width: 874, height: 402))
        let inset = GameView.landscapeTileWidth(forBoardSize: CGSize(width: 756, height: 381))
        for tile in [full, inset] {
            #expect(tile >= GameView.minCompactTileWidth)
            #expect(tile <= GameView.maxCardTileWidth)
        }
        // セーフエリアを引いた方が狭いぶん札も小さい
        #expect(inset < full)
        // 中央カラムに山札 + 場札 8 枚 + 7 スペーシングが 1 行で収まる
        #expect(rowWithDeckWidth(tile: inset) <= centerWidth(forBoardWidth: 756) + 0.5)
    }

    /// 縦に余裕がある（が横向き扱いの）サイズでは幅で決まる。
    @Test func landscapeTileIsWidthLimitedWhenTallEnough() {
        let size = CGSize(width: 1_024, height: 768)
        let tile = GameView.landscapeTileWidth(forBoardSize: size)
        #expect(tile < GameView.maxCardTileWidth)
        // 山札 + 8 枚が中央幅ぴったりに収まり、1pt 広げるともう入らない
        let center = centerWidth(forBoardWidth: size.width)
        #expect(rowWithDeckWidth(tile: tile) <= center + 0.5)
        #expect(rowWithDeckWidth(tile: tile + 1) > center)
    }

    /// 縦が足りないときは高さが札幅を決める（横幅から決まる値より小さくなる）。
    @Test func landscapeTileIsHeightLimitedWhenShort() {
        let size = CGSize(width: 900, height: 340)
        let tile = GameView.landscapeTileWidth(forBoardSize: size)
        let spacing = GameView.gridSpacing(compact: true)
        let centerWidth =
            size.width - GameView.boardPadding * 2
            - 2 * (GameView.landscapeSideColumnWidth + GameView.landscapeColumnSpacing)
        #expect(tile < floor((centerWidth - spacing * 7) / 8))
        #expect(tile > GameView.minCompactTileWidth)
    }

    /// 高さが極端に足りない場合は下限まで縮み、それ以下にはならない。
    @Test func landscapeTileClampsToMinimumWhenTooShort() {
        #expect(
            GameView.landscapeTileWidth(forBoardSize: CGSize(width: 900, height: 220))
                == GameView.minCompactTileWidth)
        #expect(
            GameView.landscapeTileWidth(forBoardSize: .zero) == GameView.minCompactTileWidth)
    }

    /// 横向きの相手裏札 8 枚が側方カラムの幅に収まる（中央にはみ出さない）。
    @Test func landscapeOpponentBacksFitTheSideColumn() {
        let width = GameView.landscapeOpponentBackWidth
        let spacing = GameView.landscapeOpponentBackSpacing
        #expect(spacing < 0)  // 重ねて並べる
        #expect(width * 8 + spacing * 7 <= GameView.landscapeSideColumnWidth)
    }

    /// 側方カラム（120pt）には獲得札サムネイルが 1 行 3 枚だけ入る。
    @Test func capturedThumbnailsWrapAtThreePerRow() {
        #expect(GameView.capturedColumns(forWidth: GameView.landscapeSideColumnWidth) == 3)
        let thumbnail = GameView.landscapeCapturedThumbnail
        let spacing = GameView.landscapeCapturedSpacing
        // 3 枚は収まり、4 枚目は入らない
        #expect(thumbnail * 3 + spacing * 2 <= GameView.landscapeSideColumnWidth)
        #expect(thumbnail * 4 + spacing * 3 > GameView.landscapeSideColumnWidth)
    }

    /// 左右の列を除いた中央カラムの幅。
    private func centerWidth(forBoardWidth width: CGFloat) -> CGFloat {
        width - GameView.boardPadding * 2
            - 2 * (GameView.landscapeSideColumnWidth + GameView.landscapeColumnSpacing)
    }

    /// 山札 + 場札 8 枚 + スペーシングの行幅。
    private func rowWithDeckWidth(tile: CGFloat) -> CGFloat {
        tile * 0.62 + 12 + tile * 8 + GameView.gridSpacing(compact: true) * 7
    }
}
