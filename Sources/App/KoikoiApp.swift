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
        #elseif os(macOS)
        // 対局は 1 つだけ自動保存・自動復元するため、複数ウィンドウは開かない
        Window("Koikoi", id: "main") {
            GameSessionView()
        }
        .defaultSize(width: 900, height: 700)
        #else
        // 起動したら前回の対局を自動復元し、無ければ対局設定から始める
        WindowGroup {
            GameSessionView()
        }
        #endif
    }
}
