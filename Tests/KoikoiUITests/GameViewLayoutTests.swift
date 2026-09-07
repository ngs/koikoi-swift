import Foundation
import Testing

@testable import KoikoiUI

/// 盤面幅に応じた札タイル幅のスケーリング規則。
@MainActor
@Suite struct GameViewLayoutTests {
    /// 横向き iPhone の寸法（既定の検証対象）。
    let phone = WideLayoutMetrics.phone
    /// macOS の寸法。
    let mac = WideLayoutMetrics.mac

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
        let full = GameView.wideTileWidth(metrics: phone, forBoardSize: CGSize(width: 874, height: 402))
        let inset = GameView.wideTileWidth(metrics: phone, forBoardSize: CGSize(width: 756, height: 381))
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
        let tile = GameView.wideTileWidth(metrics: phone, forBoardSize: size)
        #expect(tile < GameView.maxCardTileWidth)
        // 山札 + 8 枚が中央幅ぴったりに収まり、1pt 広げるともう入らない
        let center = centerWidth(forBoardWidth: size.width)
        #expect(rowWithDeckWidth(tile: tile) <= center + 0.5)
        #expect(rowWithDeckWidth(tile: tile + 1) > center)
    }

    /// 縦が足りないときは高さが札幅を決める（横幅から決まる値より小さくなる）。
    @Test func landscapeTileIsHeightLimitedWhenShort() {
        let size = CGSize(width: 900, height: 340)
        let tile = GameView.wideTileWidth(metrics: phone, forBoardSize: size)
        let spacing = GameView.gridSpacing(compact: true)
        let centerWidth =
            size.width - GameView.boardPadding * 2
            - 2 * (phone.sideColumnWidth + phone.columnSpacing)
        #expect(tile < floor((centerWidth - spacing * 7) / 8))
        #expect(tile > GameView.minCompactTileWidth)
    }

    /// 高さが極端に足りない場合は下限まで縮み、それ以下にはならない。
    @Test func landscapeTileClampsToMinimumWhenTooShort() {
        #expect(
            GameView.wideTileWidth(metrics: phone, forBoardSize: CGSize(width: 900, height: 220))
                == GameView.minCompactTileWidth)
        #expect(
            GameView.wideTileWidth(metrics: phone, forBoardSize: .zero) == GameView.minCompactTileWidth)
    }

    /// 横向きの相手裏札 8 枚が側方カラムの幅に収まる（中央にはみ出さない）。
    @Test func landscapeOpponentBacksFitTheSideColumn() {
        let width = phone.backWidth
        let spacing = phone.backSpacing
        #expect(spacing < 0)  // 重ねて並べる
        #expect(width * 8 + spacing * 7 <= phone.sideColumnWidth)
    }

    /// 側方カラム（128pt）には獲得札サムネイルが 1 行 4 枚だけ入る。
    @Test func capturedThumbnailsWrapAtFourPerRow() {
        #expect(GameView.capturedColumns(forWidth: phone.sideColumnWidth, thumbnail: phone.thumbnail) == 4)
        let thumbnail = phone.thumbnail
        let spacing = WideLayoutMetrics.thumbnailSpacing
        // 4 枚は収まり、5 枚目は入らない
        #expect(thumbnail * 4 + spacing * 3 <= phone.sideColumnWidth)
        #expect(thumbnail * 5 + spacing * 4 > phone.sideColumnWidth)
    }

    /// 相手の裏札 8 枚も同じカラムに収まったままである。
    @Test func opponentBacksStillFitTheWiderColumn() {
        let width = phone.backWidth
        let spacing = phone.backSpacing
        #expect(width * 8 + spacing * 7 <= phone.sideColumnWidth)
    }

    /// macOS のウィンドウでは高さより幅が先に効き、上限（112pt）を超えない。
    @Test func macWindowsScaleTilesWithinBounds() {
        let small = GameView.wideTileWidth(
            metrics: mac, forBoardSize: CGSize(width: 890, height: 760))
        let large = GameView.wideTileWidth(
            metrics: mac, forBoardSize: CGSize(width: 1_400, height: 900))
        #expect(small >= GameView.minCompactTileWidth)
        #expect(small < large)
        #expect(large <= GameView.maxCardTileWidth)
        // 山札 + 場札 8 枚が中央カラムに 1 行で収まる
        for (width, tile) in [(CGFloat(890), small), (CGFloat(1_400), large)] {
            let center = width - mac.horizontalPadding * 2
                - 2 * (mac.sideColumnWidth + mac.columnSpacing)
            let row = tile * 0.62 + 12 + tile * 8 + GameView.gridSpacing(compact: true) * 7
            #expect(row <= center + 0.5)
        }
    }

    /// macOS の最小ウィンドウ幅では、札がちょうど下限幅（48pt）になる。
    @Test func macMinimumWindowFitsTheSmallestTiles() {
        let tile = GameView.wideTileWidth(
            metrics: mac,
            forBoardSize: CGSize(width: GameView.wideMinBoardWidth, height: 800))
        #expect(tile == GameView.minWideTileWidth)
        // 以前のウィンドウ幅（890pt）でも開ける
        #expect(GameView.wideMinBoardWidth < 890)
    }

    /// 890×800 のウィンドウでは札が 64pt より小さくなる（iPhone と同じく縮む）。
    @Test func macNarrowWindowShrinksTilesBelowTheBaseWidth() {
        let tile = GameView.wideTileWidth(
            metrics: mac, forBoardSize: CGSize(width: 890, height: 800))
        #expect(tile > GameView.minCompactTileWidth)
        #expect(tile < GameView.cardTileWidth)
        #expect((48...56).contains(tile))
    }

    /// macOS の側方カラムにも獲得札が 1 行 4 枚入り、裏札 8 枚も収まる。
    @Test func macSideColumnFitsFourThumbnailsAndBacks() {
        #expect(
            GameView.capturedColumns(forWidth: mac.sideColumnWidth, thumbnail: mac.thumbnail) == 4)
        #expect(mac.backWidth * 8 + mac.backSpacing * 7 <= mac.sideColumnWidth)
    }

    /// 左右の列を除いた中央カラムの幅。
    private func centerWidth(forBoardWidth width: CGFloat) -> CGFloat {
        width - phone.horizontalPadding * 2
            - 2 * (phone.sideColumnWidth + phone.columnSpacing)
    }

    /// 山札 + 場札 8 枚 + スペーシングの行幅。
    private func rowWithDeckWidth(tile: CGFloat) -> CGFloat {
        tile * 0.62 + 12 + tile * 8 + GameView.gridSpacing(compact: true) * 7
    }
}
