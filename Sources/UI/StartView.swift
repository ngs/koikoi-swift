import KoikoiCore
import SwiftUI

/// タイトル / 対局設定画面。
public struct StartView: View {
    @State private var rounds = 12
    @State private var difficulty: Difficulty = .normal
    @State private var session: GameViewModel?

    public init() {}

    public var body: some View {
        if let session {
            GameView(model: session) {
                self.session = nil
            }
        } else {
            menu
        }
    }

    private var menu: some View {
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
                session = GameViewModel(rounds: rounds, difficulty: difficulty)
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

#Preview("タイトル") {
    StartView()
}
