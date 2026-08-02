import KoikoiUI
import SwiftUI

@main
struct KoikoiApp: App {
    var body: some Scene {
        #if os(visionOS)
        // visionOS は DocumentGroup の環境アクション（newDocument 等）が使えないため、
        // セッション型のメインフロー（設定 → 対局・.koikoi の保存/読込付き）を先頭シーンにする
        WindowGroup(id: "launcher") {
            VisionMainView()
        }
        .defaultSize(width: 900, height: 760)
        #endif

        // 1 対局 = 1 ファイル（.koikoi）。未保存の変更は閉じるときに
        // OS が保存を促す（Chess.app と同様の文書ベース構成）。
        DocumentGroup(
            newDocument: { KoikoiGameDocument() },
            editor: { configuration in
                GameDocumentView(document: configuration.document)
            })

        #if os(visionOS)
        // AR 空間ボード: フェルト盤を目の前に水平配置し、俯瞰でプレイする
        WindowGroup(id: "spatialBoard") {
            SpatialBoardView()
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.7, height: 0.45, depth: 0.6, in: .meters)
        #endif

        #if os(iOS)
        // iOS は文書ブラウザの前に「新しい対局」から始められるランチャーを出す
        // （visionOS では DocumentGroupLaunchScene が機能しないため上の専用シーンを使う）
        DocumentGroupLaunchScene("こいこい") {
            NewDocumentButton("新しい対局")
        } background: {
            Color(red: 0.10, green: 0.28, blue: 0.20)
        }
        #endif
    }
}
