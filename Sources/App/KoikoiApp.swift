import KoikoiUI
import SwiftUI

@main
struct KoikoiApp: App {
    var body: some Scene {
        // 1 対局 = 1 ファイル（.koikoi）。未保存の変更は閉じるときに
        // OS が保存を促す（Chess.app と同様の文書ベース構成）。
        DocumentGroup(newDocument: { KoikoiGameDocument() }) { configuration in
            GameDocumentView(document: configuration.document)
        }

        #if os(visionOS)
        // AR 空間ボード: フェルト盤を目の前に水平配置し、俯瞰でプレイする
        WindowGroup(id: "spatialBoard") {
            SpatialBoardView()
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.7, height: 0.45, depth: 0.6, in: .meters)
        #endif

        #if os(visionOS) || os(iOS)
        // visionOS/iOS は文書未選択時に空のプレースホルダが出るため、
        // 「新しい対局」から始められるランチャー画面を用意する
        DocumentGroupLaunchScene("こいこい") {
            NewDocumentButton("新しい対局")
        } background: {
            Color(red: 0.10, green: 0.28, blue: 0.20)
        }
        #endif
    }
}
