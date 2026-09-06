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
    /// 選択中の配色（設定画面のピッカーと共有する）。
    @AppStorage(KoikoiTheme.storageKey)
    private var themeRaw = KoikoiTheme.felt.rawValue
    private var theme: KoikoiTheme { KoikoiTheme(rawValue: themeRaw) ?? .felt }
    #if os(iOS)
    @Environment(\.verticalSizeClass)
    private var verticalSizeClass
    /// 横向き iPhone。盤面に高さの余裕が無いため、スコアボードはツールバーに載せる。
    private var isLandscapePhone: Bool { verticalSizeClass == .compact }
    #endif

    /// デバッグ用の対局数上書きキー（起動引数 `-KoikoiDebugRounds <n>`）。
    static let debugRoundsKey = "KoikoiDebugRounds"

    public init(store: GameStore = .shared) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            content
                .quitToolbar(active: model != nil && !showsLandscapeChrome) {
                    confirmingQuit = true
                }
                .landscapeChromeToolbar(
                    model: model, active: showsLandscapeChrome, palette: palette
                ) {
                    confirmingQuit = true
                }
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
        // 対局中は卓の色で画面全体を塗る（横向きでセーフエリアの帯が黒く残らないように）
        .background {
            if model != nil {
                palette.table.ignoresSafeArea()
            }
        }
        .koikoiTheme(theme)
        .onAppear {
            GameCenterService.shared.authenticate()
            // Game Center のアクセスポイントは左上の見出しと場所を取り合うため対局中は隠す
            GameCenterService.shared.setAccessPointVisible(model == nil)
            guard !didRestore else { return }
            didRestore = true
            if let saved = store.load() {
                start(record: saved)
            }
        }
        .onChange(of: model == nil) { _, isSetup in
            GameCenterService.shared.setAccessPointVisible(isSetup)
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

    private var palette: KoikoiPalette { KoikoiPalette(theme: theme) }

    /// 横向き iPhone のときだけ、スコアボードと陣営の見出しをツールバーに載せる。
    private var showsLandscapeChrome: Bool {
        #if os(iOS)
        return isLandscapePhone && model != nil
        #else
        return false
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

private extension View {
    /// 対局をやめるボタン（縦向き・iPad・macOS 用）。
    @ViewBuilder
    func quitToolbar(active: Bool, quit: @escaping () -> Void) -> some View {
        if active {
            toolbar {
                ToolbarItem(placement: KoikoiToolbar.quitPlacement) {
                    KoikoiToolbar.quitButton(quit)
                }
            }
        } else {
            self
        }
    }

    /// 横向き iPhone のツールバー: 左に「You」、中央にスコアボード、
    /// 右に「Opponent」と終了ボタン（X が一番外側）。
    @ViewBuilder
    func landscapeChromeToolbar(
        model: GameViewModel?, active: Bool, palette: KoikoiPalette,
        quit: @escaping () -> Void
    ) -> some View {
        #if os(iOS)
        if let model, active {
            toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    KoikoiToolbar.header(Text("You", bundle: .module), palette: palette)
                }
                // 見出しはボタンではないので項目ごとの地は敷かない（ぼかしはバーが担う）
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .principal) {
                    GameScoreboard(model: model, style: .strip)
                        .fixedSize()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    KoikoiToolbar.header(Text("Opponent", bundle: .module), palette: palette)
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) {
                    KoikoiToolbar.quitButton(quit)
                }
            }
            // 下を流れる札は、バー自体のぼかし越しに見せる
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

/// ツールバーの部品（縦向き・横向きで同じボタンと見出しを使う）。
private enum KoikoiToolbar {
    /// Game Center のアクセスポイント（左上固定）と重ならないよう右上に置く。
    static var quitPlacement: ToolbarItemPlacement {
        #if os(macOS)
        return .primaryAction
        #else
        return .topBarTrailing
        #endif
    }

    @MainActor
    static func quitButton(_ quit: @escaping () -> Void) -> some View {
        Button(String(localized: "Quit Game", bundle: .module), systemImage: "xmark") {
            quit()
        }
    }

    #if os(iOS)
    /// 横向きのツールバーに置く陣営の見出し（ボタンに見えないよう文字だけ）。
    @MainActor
    static func header(_ title: Text, palette: KoikoiPalette) -> some View {
        title
            .font(.title3.bold())
            .foregroundStyle(palette.ink)
            .fixedSize()  // ツールバーに詰められて 1 文字に切られないようにする
    }
    #endif
}
#endif
