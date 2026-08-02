import KoikoiAI
import KoikoiCore
import SwiftUI

/// 対局画面。上から相手陣・場・自陣の三段構成（全プラットフォーム共有）。
public struct GameView: View {
    @State private var model: GameViewModel
    private let onExit: (() -> Void)?

    public init(model: GameViewModel, onExit: (() -> Void)? = nil) {
        _model = State(initialValue: model)
        self.onExit = onExit
    }

    public var body: some View {
        VStack(spacing: 8) {
            header
            opponentArea
            Spacer(minLength: 4)
            fieldArea
            Spacer(minLength: 4)
            playerArea
        }
        .padding(12)
        .background(Color(red: 0.10, green: 0.28, blue: 0.20))
        .overlay { overlays }
        .animation(.default, value: model.game.field)
        .animation(.default, value: model.game.hands)
    }

    // MARK: - 区画

    private var header: some View {
        HStack {
            Text("\(Month(rawValue: (model.game.round - 1) % 12)?.oldName ?? "") ・ 第\(model.game.round)局/\(model.game.maxRounds)")
                .font(.headline)
            Spacer()
            Text("あなた \(model.game.score(for: .player))文 - 相手 \(model.game.score(for: .opponent))文")
                .font(.subheadline.monospacedDigit())
        }
        .foregroundStyle(.white)
    }

    private var opponentArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                ForEach(0..<model.game.hand(for: .opponent).count, id: \.self) { _ in
                    CardBack().frame(width: 34)
                }
                Spacer()
                if let line = model.opponentLine {
                    Text(line)
                        .font(.caption)
                        .padding(6)
                        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            CapturedRow(cards: model.game.captured(for: .opponent), cardWidth: 30)
            YakuBadges(yakus: model.opponentYaku)
        }
    }

    private var fieldArea: some View {
        VStack(spacing: 8) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 56, maximum: 72), spacing: 8)],
                spacing: 8
            ) {
                ForEach(model.game.field) { card in
                    FieldCardView(
                        card: card,
                        highlighted: model.fieldCandidates.contains(card)
                    ) {
                        model.tapFieldCard(card)
                    }
                }
            }
            HStack {
                Label("山 \(model.game.deck.count)", systemImage: "square.stack")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                statusText
            }
        }
    }

    private var statusText: some View {
        Group {
            switch model.prompt {
            case .selectHand:
                Text("手札を選んでください")
            case .selectField:
                Text("取る場札を選んでください")
            case .opponentTurn:
                Text("相手の番…")
            case .decideKoikoi, .roundEnd, .matchEnd:
                Text("")
            }
        }
        .font(.caption)
        .foregroundStyle(.yellow)
    }

    private var playerArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            YakuBadges(yakus: model.playerYaku)
            CapturedRow(cards: model.game.captured(for: .player), cardWidth: 30)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 56, maximum: 72), spacing: 8)],
                spacing: 8
            ) {
                ForEach(model.game.hand(for: .player)) { card in
                    Button {
                        model.tapHandCard(card)
                    } label: {
                        CardImage(card)
                            .overlay {
                                if model.pendingHandCard == card {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(.yellow, lineWidth: 3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    // 手札選択中と場札選択中（解除・選び直し）はタップ可能
                    .disabled(model.prompt != .selectHand && model.pendingHandCard == nil)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - オーバーレイ

    @ViewBuilder private var overlays: some View {
        switch model.prompt {
        case .decideKoikoi(let newYaku):
            dialog {
                Text("役が成立！").font(.title2.bold())
                ForEach(newYaku, id: \.self) { yaku in
                    Text("\(yaku.kind.rawValue)（\(yaku.points)文）")
                }
                HStack(spacing: 16) {
                    Button("こいこい！") { model.decide(koikoi: true) }
                        .buttonStyle(.borderedProminent)
                    Button("勝負") { model.decide(koikoi: false) }
                        .buttonStyle(.bordered)
                }
            }
        case .roundEnd(let outcome):
            dialog {
                Text(roundEndTitle(outcome)).font(.title2.bold())
                if outcome.winner != nil {
                    Text("\(outcome.points)文獲得")
                }
                Button("次へ") { model.proceedAfterRound() }
                    .buttonStyle(.borderedProminent)
            }
        case .matchEnd(let winner):
            dialog {
                Text(matchEndTitle(winner)).font(.title.bold())
                Text("あなた \(model.game.score(for: .player))文 - 相手 \(model.game.score(for: .opponent))文")
                if let onExit {
                    Button("タイトルへ") { onExit() }
                        .buttonStyle(.borderedProminent)
                }
            }
        default:
            EmptyView()
        }
    }

    private func dialog(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 12)
    }

    private func roundEndTitle(_ outcome: RoundOutcome) -> String {
        switch outcome.winner {
        case .player: "あなたの勝ち！"
        case .opponent: "相手の勝ち"
        case nil: "流局"
        }
    }

    private func matchEndTitle(_ winner: Seat?) -> String {
        switch winner {
        case .player: "対局勝利！"
        case .opponent: "対局敗北…"
        case nil: "引き分け"
        }
    }
}

#Preview("対局") {
    GameView(model: GameViewModel(rounds: 3, difficulty: .normal, seed: 42))
}
