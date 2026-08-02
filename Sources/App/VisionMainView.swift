#if os(visionOS)
import KoikoiAI
import KoikoiUI
import SwiftUI
import UniformTypeIdentifiers

/// visionOS のメインフロー。DocumentGroup の環境アクションが使えないため、
/// 設定 → 対局のセッション型フローに、.koikoi の書き出し/読み込みを付ける。
struct VisionMainView: View {
    @State private var model: GameViewModel?
    @State private var moves: [Move] = []
    @State private var exporting = false
    @State private var importing = false

    var body: some View {
        Group {
            if let model {
                GameView(model: model)
                    .toolbar {
                        ToolbarItemGroup(placement: .bottomOrnament) {
                            Button("空間で遊ぶ", systemImage: "cube") {
                                SpatialSession.shared.model = model
                                openWindow(id: "spatialBoard")
                            }
                            Button("保存", systemImage: "square.and.arrow.down") {
                                exporting = true
                            }
                            Button("タイトルへ", systemImage: "house") {
                                self.model = nil
                                moves = []
                            }
                        }
                    }
            } else {
                VStack(spacing: 20) {
                    GameSetupView { rounds, difficulty in
                        start(record: GameRecord(
                            rounds: rounds, difficulty: difficulty,
                            seed: UInt64.random(in: .min ... .max)))
                    }
                    Button("保存した対局を開く", systemImage: "folder") {
                        importing = true
                    }
                }
            }
        }
        .fileExporter(
            isPresented: $exporting,
            document: model.map { KoikoiGameDocument(record: $0.makeRecord(moves: moves)) },
            contentType: .koikoiGame,
            defaultFilename: "Koikoi"
        ) { _ in }
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.koikoiGame]
        ) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url),
                let record = try? JSONDecoder().decode(GameRecord.self, from: data) else { return }
            start(record: record)
        }
    }

    @Environment(\.openWindow)
    private var openWindow

    private func start(record: GameRecord) {
        moves = record.moves
        let model = GameViewModel(record: record)
        model.onMoveApplied = { moves.append($0) }
        self.model = model
    }
}
#endif
