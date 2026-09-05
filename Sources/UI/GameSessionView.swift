#if !os(visionOS)
import KoikoiCore
import SwiftUI

/// iPhone / iPad / macOS のルート画面。
/// 起動時に保存済みの対局があればそのまま復元し、無ければ対局設定から始める。
/// 手が進むたびに `GameStore` へ自動保存するため、ユーザーはファイルを意識しない。
public struct GameSessionView: View {
    private let store: GameStore
    @State private var model: GameViewModel?
    @State private var record: GameRecord?
    @State private var confirmingQuit = false
    @State private var didRestore = false
    @Environment(\.scenePhase)
    private var scenePhase

    public init(store: GameStore = .shared) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            content
                .toolbar { quitToolbar }
                .confirmationDialog(
                    "対局をやめますか？",
                    isPresented: $confirmingQuit,
                    titleVisibility: .visible
                ) {
                    Button("やめる", role: .destructive) { quit() }
                    Button("続ける", role: .cancel) {}
                } message: {
                    Text("保存された対局は削除されます。")
                }
        }
        .onAppear {
            GameCenterService.shared.authenticate()
            guard !didRestore else { return }
            didRestore = true
            if let saved = store.load() {
                start(record: saved)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // バックグラウンド遷移時の保険（通常は 1 手ごとに保存済み）
            guard phase != .active, let record else { return }
            store.save(record)
        }
    }

    @ViewBuilder private var content: some View {
        if let model {
            GameView(model: model, onExit: quit)
        } else {
            GameSetupView { rounds, difficulty in
                let record = GameRecord(
                    rounds: rounds,
                    difficulty: difficulty,
                    seed: UInt64.random(in: .min ... .max))
                store.save(record)
                start(record: record)
            }
        }
    }

    @ToolbarContentBuilder private var quitToolbar: some ToolbarContent {
        if model != nil {
            ToolbarItem(placement: Self.quitPlacement) {
                Button("対局をやめる", systemImage: "xmark") {
                    confirmingQuit = true
                }
            }
        }
    }

    private static var quitPlacement: ToolbarItemPlacement {
        #if os(macOS)
        return .navigation
        #else
        return .topBarLeading
        #endif
    }

    private func start(record: GameRecord) {
        self.record = record
        let model = GameViewModel(record: record)
        model.onMoveApplied = { move in
            self.record?.moves.append(move)
            guard let updated = self.record else { return }
            store.save(updated)
        }
        self.model = model
    }

    private func quit() {
        store.clear()
        model = nil
        record = nil
    }
}
#endif
