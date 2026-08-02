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
    }
}
