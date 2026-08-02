import KoikoiAI
import KoikoiCore
import SwiftUI
import UniformTypeIdentifiers

public extension UTType {
    /// 対局記録ファイル（.koikoi）。
    static let koikoiGame = UTType(exportedAs: "io.ngs.Koikoi.game")
}

/// 1 対局 = 1 ファイルの文書（Chess.app と同様の扱い）。
/// 変更は undoManager 経由でマークされ、未保存で閉じると OS が保存を促す。
public final class KoikoiGameDocument: ReferenceFileDocument {
    public static var readableContentTypes: [UTType] { [.koikoiGame] }

    /// 対局記録。新規文書では設定が決まるまで nil。
    @Published public var record: GameRecord?

    public init() {
        record = nil
    }

    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        record = try JSONDecoder().decode(GameRecord.self, from: data)
    }

    public func snapshot(contentType _: UTType) throws -> GameRecord? {
        record
    }

    public func fileWrapper(
        snapshot: GameRecord?, configuration _: WriteConfiguration
    ) throws -> FileWrapper {
        guard let snapshot else {
            throw CocoaError(.fileWriteUnknown)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(snapshot))
    }
}

/// 文書 1 つ分の画面。未設定なら対局設定、設定済みならリプレイして対局へ。
public struct GameDocumentView: View {
    @ObservedObject private var document: KoikoiGameDocument
    @Environment(\.undoManager)
    private var undoManager
    #if os(visionOS)
    @Environment(\.openWindow)
    private var openWindow
    #endif
    @State private var model: GameViewModel?

    public init(document: KoikoiGameDocument) {
        self.document = document
    }

    public var body: some View {
        Group {
            if let model {
                GameView(model: model)
                    #if os(visionOS)
                    .toolbar {
                        ToolbarItem(placement: .bottomOrnament) {
                            Button("空間で遊ぶ", systemImage: "cube") {
                                SpatialSession.shared.model = model
                                openWindow(id: "spatialBoard")
                            }
                        }
                    }
                    #endif
            } else if let record = document.record {
                // 既存ファイル: 記録をリプレイして再開
                Color.clear
                    .onAppear { startGame(record: record) }
            } else {
                GameSetupView { rounds, difficulty in
                    let record = GameRecord(
                        rounds: rounds,
                        difficulty: difficulty,
                        seed: UInt64.random(in: .min ... .max))
                    document.record = record
                    // 新規作成した時点で「未保存の変更あり」にする
                    markEdited()
                    startGame(record: record)
                }
            }
        }
        .onAppear { GameCenterService.shared.authenticate() }
    }

    private func startGame(record: GameRecord) {
        let model = GameViewModel(record: record)
        model.onMoveApplied = { [weak document] move in
            guard document != nil else { return }
            document?.record?.moves.append(move)
            markEdited()
        }
        self.model = model
    }

    /// 変更マークを付ける。実際の取り消しは提供しないため、
    /// undo スタックが際限なく育たないよう 1 段に制限する。
    private func markEdited() {
        guard let undoManager else { return }
        undoManager.levelsOfUndo = 1
        undoManager.registerUndo(withTarget: document) { _ in }
    }
}
