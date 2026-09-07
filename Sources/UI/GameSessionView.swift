#if !os(visionOS)
import SwiftUI

#if os(macOS)
import AppKit
#endif

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
    /// 背景を透過するか（対局設定画面のトグルと共有する）。
    @AppStorage(KoikoiAppearance.translucencyStorageKey)
    private var translucentWindow = KoikoiAppearance.defaultTranslucency
    /// 盤面が三列レイアウトか（GameView から通知される）。
    /// 三列のときはスコアボードと陣営の見出しをツールバーに載せる。
    @State private var wideBoard = false

    /// デバッグ用の対局数上書きキー（起動引数 `-KoikoiDebugRounds <n>`）。
    static let debugRoundsKey = "KoikoiDebugRounds"

    public init(store: GameStore = .shared) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            content
                .quitToolbar(
                    active: model != nil && !showsWideChrome,
                    confirming: $confirmingQuit, quit: quit)
                .wideChromeToolbar(
                    model: model, active: showsWideChrome, palette: palette,
                    confirming: $confirmingQuit, quit: quit)
        }
        // 対局中は卓の色で画面全体を塗る（横向きでセーフエリアの帯が黒く残らないように）。
        // 透過が有効なときは盤面側で薄く重ねるので、ここでは塗らない。
        .background {
            if model != nil, !usesTranslucentWindow {
                palette.table.ignoresSafeArea()
            }
        }
        .modifier(TranslucentWindowBackground(active: usesTranslucentWindow && model != nil))
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
            GameView(model: model, onExit: quit) { wide in
                // 盤面のレイアウトに合わせてツールバーの陣営見出しを出し入れする
                wideBoard = wide
            }
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

    /// 背景を透過する設定（macOS / visionOS でのみ選べる）。
    private var usesTranslucentWindow: Bool {
        KoikoiAppearance.isAvailable && translucentWindow
    }

    /// スコアボードと陣営の見出しをツールバーに載せるか
    /// （macOS は常に、iOS は横向き iPhone のときだけ）。
    private var showsWideChrome: Bool {
        #if os(macOS) || os(iOS)
        return model != nil && wideBoard
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
    func quitToolbar(
        active: Bool, confirming: Binding<Bool>, quit: @escaping () -> Void
    ) -> some View {
        if active {
            toolbar {
                ToolbarItem(placement: KoikoiToolbar.quitPlacement) {
                    KoikoiToolbar.quitButton(confirming: confirming, quit: quit)
                }
            }
        } else {
            self
        }
    }

    /// 三列レイアウトのツールバー: 左に「You」、中央にスコアボード、
    /// 右に「Opponent」と終了ボタン（X が一番外側）。
    @ViewBuilder
    func wideChromeToolbar(
        model: GameViewModel?, active: Bool, palette: KoikoiPalette,
        confirming: Binding<Bool>, quit: @escaping () -> Void
    ) -> some View {
        #if os(iOS) || os(macOS)
        if let model, active {
            toolbar {
                ToolbarItem(placement: KoikoiToolbar.headerLeadingPlacement) {
                    KoikoiToolbar.header(Text("You", bundle: .module), palette: palette)
                }
                // 見出しはボタンではないので項目ごとの地は敷かない（ぼかしはバーが担う）
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .principal) {
                    GameScoreboard(model: model, style: .strip)
                        .fixedSize()
                }
                ToolbarItem(placement: KoikoiToolbar.quitPlacement) {
                    KoikoiToolbar.header(Text("Opponent", bundle: .module), palette: palette)
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: KoikoiToolbar.quitPlacement) {
                    KoikoiToolbar.quitButton(confirming: confirming, quit: quit)
                }
            }
            // 下を流れる札は、バー自体のぼかし越しに見せる
            .modifier(WideToolbarBackground())
            // ウィンドウ名はスコアボードと場所を取り合うので対局中は出さない
            .navigationTitle(Text(verbatim: ""))
        } else {
            self
        }
        #else
        self
        #endif
    }
}

/// 三列レイアウトのツールバーの地（下を流れる札をぼかす）。
private struct WideToolbarBackground: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.toolbarBackgroundVisibility(.visible, for: .navigationBar)
        #elseif os(macOS)
        content.toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        #else
        content
        #endif
    }
}

/// macOS の system テーマでウィンドウをマテリアルにする（デスクトップが透ける）。
private struct TranslucentWindowBackground: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        #if os(macOS)
        if active {
            // SwiftUI のマテリアルは非アクティブなウィンドウでぼかしを止めて
            // 不透明になるため、状態を固定した NSVisualEffectView を地に敷き、
            // ウィンドウ自体は透明にする。
            content
                .background {
                    WindowMaterial().ignoresSafeArea()
                }
                .containerBackground(.clear, for: .window)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

#if os(macOS)
/// ウィンドウの地に敷くマテリアル。
/// `NSVisualEffectView` の既定 (`followsWindowActiveState`) は前面でないときに
/// ぼかしを止めるので、`.active` に固定して背面でも透過を保つ。
private struct WindowMaterial: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        configure(view)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context _: Context) {
        configure(view)
    }

    private func configure(_ view: NSVisualEffectView) {
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
    }
}
#endif

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

    /// 「You」の見出しを置く側。
    static var headerLeadingPlacement: ToolbarItemPlacement {
        #if os(macOS)
        return .navigation
        #else
        return .topBarLeading
        #endif
    }

    /// 確認ダイアログはボタン自身に付ける（regular 幅では popover になり、
    /// ルートに付けると吹き出しがボタンではなく画面中央から出る）。
    @MainActor
    static func quitButton(
        confirming: Binding<Bool>, quit: @escaping () -> Void
    ) -> some View {
        Button(String(localized: "Quit Game", bundle: .module), systemImage: "xmark") {
            confirming.wrappedValue = true
        }
        .confirmationDialog(
            Text("Quit this game?", bundle: .module),
            isPresented: confirming,
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

    #if os(iOS) || os(macOS)
    /// ツールバーに置く陣営の見出し（ボタンに見えないよう文字だけ）。
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
