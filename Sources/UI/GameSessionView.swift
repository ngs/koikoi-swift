#if !os(visionOS)
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

    /// デバッグ用の対局数上書きキー（起動引数 `-KoikoiDebugRounds <n>`）。
    static let debugRoundsKey = "KoikoiDebugRounds"

    public init(store: GameStore = .shared) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            content
                .toolbar { quitToolbar }
                .confirmationDialog(
                    Text("Quit this game?", bundle: .module),
                    isPresented: $confirmingQuit,
                    titleVisibility: .visible
                ) {
                    Button(String(localized: "Quit", bundle: .module), role: .destructive) {
                        quit()
                    }
                    Button(String(localized: "Continue", bundle: .module), role: .cancel) {}
                } message: {
                    Text("The saved game will be deleted.", bundle: .module)
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
                    rounds: Self.resolvedRounds(rounds),
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
                Button(
                    String(localized: "Quit Game", bundle: .module),
                    systemImage: "xmark"
                ) {
                    confirmingQuit = true
                }
            }
        }
    }

    /// Game Center のアクセスポイント（左上固定）と重ならないよう右上に置く。
    private static var quitPlacement: ToolbarItemPlacement {
        #if os(macOS)
        return .primaryAction
        #else
        return .topBarTrailing
        #endif
    }

    /// デバッグ時のみ、起動引数 `-KoikoiDebugRounds <n>` で対局数を上書きする
    /// （終了フローの動作確認用。Release ビルドには含めない）。
    static func resolvedRounds(
        _ rounds: Int, defaults: UserDefaults = .standard
    ) -> Int {
        #if DEBUG
        let override = defaults.integer(forKey: Self.debugRoundsKey)
        if override >= 1 { return override }
        #endif
        return rounds
    }

    private func start(record: GameRecord) {
        self.record = record
        let model = GameViewModel(record: record)
        model.onMoveApplied = { move in
            self.record?.moves.append(move)
            guard let updated = self.record else { return }
            store.save(updated)
        }
        // 対局が終わった時点で保存を捨てる（結果表示中に kill されても復元しない）
        model.onMatchEnd = { _ in
            store.clear()
            self.record = nil
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
