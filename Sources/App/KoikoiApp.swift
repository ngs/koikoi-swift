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
