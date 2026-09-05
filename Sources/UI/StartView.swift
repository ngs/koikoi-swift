import KoikoiCore
import SwiftUI

/// 対局設定画面（新規文書の最初の画面）。
public struct GameSetupView: View {
    @State private var rounds = 12
    @State private var difficulty: Difficulty = .normal
    private let onStart: (Int, Difficulty) -> Void

    public init(onStart: @escaping (Int, Difficulty) -> Void) {
        self.onStart = onStart
    }

    public var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                // 上段はアプリ名、下段は副題（言語ごとに自然な並びになるよう別キーにする）
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
