import KoikoiUI
import SwiftUI

@main
struct KoikoiApp: App {
    var body: some Scene {
        #if os(visionOS)
        // visionOS は空間ボード一本。実寸大のフェルト盤を volumetric に置き、
        // 対局設定・保存/読込もボード上のガラスパネルで完結させる
        WindowGroup(id: "spatialBoard") {
            SpatialBoardView()
        }
        .windowStyle(.volumetric)
        .volumeWorldAlignment(.gravityAligned)
        .defaultSize(width: 0.9, height: 0.5, depth: 0.8, in: .meters)
        // 起動時は目の高さではなく、正面やや下（卓上の高さ）に出して見下ろせるようにする
        .defaultWindowPlacement { _, _ in
            WindowPlacement(.utilityPanel)
        }
        #else
        // 1 対局 = 1 ファイル（.koikoi）。未保存の変更は閉じるときに
        // OS が保存を促す（Chess.app と同様の文書ベース構成）。
        DocumentGroup(
            newDocument: { KoikoiGameDocument() },
            editor: { configuration in
                GameDocumentView(document: configuration.document)
            })
        #endif

        #if os(iOS)
        // iOS は文書ブラウザの前に「新しい対局」から始められるランチャーを出す
        DocumentGroupLaunchScene("こいこい") {
            NewDocumentButton("新しい対局")
        } background: {
            Color(red: 0.10, green: 0.28, blue: 0.20)
        }
        #endif
    }
}
