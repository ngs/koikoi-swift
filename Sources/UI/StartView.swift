import KoikoiCore
import SwiftUI

/// 対局設定画面（新規文書の最初の画面）。
public struct GameSetupView: View {
    @State private var rounds = 12
    @State private var difficulty: Difficulty = .normal
    /// 盤面の配色（対局画面と `@AppStorage` で共有する）。
    @AppStorage(KoikoiTheme.storageKey)
    private var themeRaw = KoikoiTheme.felt.rawValue
    private var theme: KoikoiTheme { KoikoiTheme(rawValue: themeRaw) ?? .felt }
    /// 背景を透過するか（macOS / visionOS のみ）。
    @AppStorage(KoikoiAppearance.translucencyStorageKey)
    private var translucentWindow = KoikoiAppearance.defaultTranslucency
    private let onStart: (Int, Difficulty) -> Void

    public init(onStart: @escaping (Int, Difficulty) -> Void) {
        self.onStart = onStart
    }

    /// 選択中の配色のミニチュア（卓・裏札・強調枠・得点タイル）。
    private var themePreview: some View {
        let palette = KoikoiPalette(theme: theme)
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(palette.table)
            .frame(height: 72)
            .overlay {
                HStack(spacing: 12) {
                    CardBack()
                        .frame(width: 34)
                    CardImage(Card.all[0])
                        .frame(width: 34)
                        .overlay {
                            CardShape()
                                .stroke(palette.highlight, lineWidth: 3)
                        }
                    PunchedBadge(
                        text: "0",
                        font: .title3.bold().monospacedDigit(),
                        verticalPadding: 4,
                        cornerRadius: 8,
                        minWidth: 44)
                }
            }
            .koikoiTheme(theme)
            .animation(.default, value: themeRaw)
    }

    public var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                // アプリアイコンの絵柄（メインバンドルの AppIconArtwork.imageset、Scripts/generate-icons.sh が生成）
                Image("AppIconArtwork", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .accessibilityHidden(true)
                Text("Koikoi", bundle: .module)
                    .font(.system(size: 56, weight: .bold))
                Text("Hanafuda Koi-Koi", bundle: .module)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                Picker(selection: $rounds) {
                    Text("3 Rounds", bundle: .module).tag(3)
                    Text("6 Rounds", bundle: .module).tag(6)
                    Text("12 Rounds", bundle: .module).tag(12)
                } label: {
                    Text("Rounds", bundle: .module)
                }
                .pickerStyle(.segmented)

                Picker(selection: $difficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { level in
                        Text(verbatim: level.localizedLabel).tag(level)
                    }
                } label: {
                    Text("Difficulty", bundle: .module)
                }
                .pickerStyle(.segmented)

                Picker(selection: $themeRaw) {
                    ForEach(KoikoiTheme.allCases) { theme in
                        Text(verbatim: theme.localizedName).tag(theme.rawValue)
                    }
                } label: {
                    Text("Theme", bundle: .module)
                }
                .pickerStyle(.segmented)

                if KoikoiAppearance.isAvailable {
                    Toggle(isOn: $translucentWindow) {
                        Text("Translucent Background", bundle: .module)
                    }
                }

                themePreview
            }
            .frame(maxWidth: 420)

            Button {
                onStart(rounds, difficulty)
            } label: {
                Text("Start Game", bundle: .module)
                    .font(.title3.bold())
                    .padding(.horizontal, 32)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview("Game Setup") {
    GameSetupView { _, _ in }
}
