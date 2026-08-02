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
                Text("こいこい")
                    .font(.system(size: 56, weight: .bold))
                Text("Koikoi")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                Picker("対局数", selection: $rounds) {
                    Text("三月（3局）").tag(3)
                    Text("六月（6局）").tag(6)
                    Text("十二月（12局）").tag(12)
                }
                .pickerStyle(.segmented)

                Picker("難易度", selection: $difficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
            .frame(maxWidth: 420)

            Button {
                onStart(rounds, difficulty)
            } label: {
                Text("対局開始")
                    .font(.title3.bold())
                    .padding(.horizontal, 32)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview("対局設定") {
    GameSetupView { _, _ in }
}
