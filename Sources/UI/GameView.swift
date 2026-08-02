import KoikoiAI
import KoikoiCore
import SwiftUI

/// 対局画面。上から相手陣・場・自陣の三段構成（全プラットフォーム共有）。
/// 操作系: タップ / ドラッグ&ドロップ（手札→場）/ 十字キー + Enter・Esc。
public struct GameView: View {
    @State private var model: GameViewModel
    @FocusState private var boardFocused: Bool
    private let onExit: (() -> Void)?
    /// D&D の受け皿を張るか。ImageRenderer はドロップ受けのバッキングビューを
    /// 描画できず禁止マークのプレースホルダになるため、スナップショット描画時のみ
    /// false にする（実アプリでは常に true）。
    private let dropTargetsEnabled: Bool

    public init(
        model: GameViewModel,
        dropTargetsEnabled: Bool = true,
        onExit: (() -> Void)? = nil
    ) {
        _model = State(initialValue: model)
        self.dropTargetsEnabled = dropTargetsEnabled
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
        .focusable()
        .focusEffectDisabled()
        .focused($boardFocused)
        .onAppear { boardFocused = true }
        .onKeyPress(.leftArrow) { move(.left) }
        .onKeyPress(.rightArrow) { move(.right) }
        .onKeyPress(.upArrow) { move(.up) }
        .onKeyPress(.downArrow) { move(.down) }
        .onKeyPress(.return) { activate() }
        .onKeyPress(.space) { activate() }
        .onKeyPress(.escape) {
            model.cancelFieldSelection()
            return .handled
        }
    }

    private func move(_ direction: GameViewModel.MoveDirection) -> KeyPress.Result {
        model.moveCursor(direction)
        return .handled
    }

    private func activate() -> KeyPress.Result {
        model.activateCursor()
        return .handled
    }

    /// ドロップ受けを条件付きで張る（スナップショット描画時は無効化）。
    @ViewBuilder
    private func cardDropTarget(_ content: some View, on target: Card?) -> some View {
        if dropTargetsEnabled {
            content.dropDestination(for: CardDragPayload.self) { payloads, _ in
                model.dropHandCard(id: payloads.first?.id, on: target)
            }
        } else {
            content
        }
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
            }
            YakuBadges(yakus: model.opponentYaku)
            CapturedDetail(cards: model.game.captured(for: .opponent), cardWidth: 30)
        }
    }

    private var fieldArea: some View {
        VStack(spacing: 8) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 56, maximum: 72), spacing: 8)],
                spacing: 8
            ) {
                ForEach(Array(model.game.field.enumerated()), id: \.element.id) { index, card in
                    cardDropTarget(
                        FieldCardView(
                            card: card,
                            highlighted: model.highlightedFieldCards.contains(card),
                            focused: model.cursor == .field(index),
                            dimmed: model.isSelectingField && !model.fieldCandidates.contains(card),
                            tappable: model.fieldCandidates.contains(card)
                        ) {
                            model.tapFieldCard(card)
                        },
                        on: card)
                }
            }
            .background {
                // 空きへの捨て札ドロップ受け（透明）
                cardDropTarget(Color.clear.contentShape(Rectangle()), on: nil)
            }
            HStack(spacing: 12) {
                DeckStack(remaining: model.game.deck.count)
                if let drawn = model.drawnCard {
                    HStack(spacing: 4) {
                        Text("引いた札:")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        CardImage(drawn)
                            .frame(width: 30)
                    }
                }
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
                Text("取る場札を選んでください（Esc で戻る）")
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
            CapturedDetail(
                cards: model.game.captured(for: .player),
                reaches: model.playerReaches,
                cardWidth: 30)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 56, maximum: 72), spacing: 8)],
                spacing: 8
            ) {
                ForEach(Array(model.game.hand(for: .player).enumerated()), id: \.element.id) { index, card in
                    HandCardView(
                        card: card,
                        matchCount: model.game.matchingFieldCards(for: card).count,
                        selected: model.pendingHandCard == card,
                        focused: model.cursor == .hand(index),
                        tappable: model.prompt == .selectHand || model.pendingHandCard != nil
                    ) {
                        model.tapHandCard(card)
                    }
                    #if os(macOS)
                    .onHover { hovering in
                        model.hoverHandCard = hovering ? card : nil
                    }
                    #endif
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
                        .overlay { dialogFocusRing(when: model.dialogKoikoiSelected) }
                    Button("勝負") { model.decide(koikoi: false) }
                        .buttonStyle(.bordered)
                        .overlay { dialogFocusRing(when: !model.dialogKoikoiSelected) }
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

    private func dialogFocusRing(when selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(.yellow, lineWidth: selected ? 3 : 0)
            .padding(-3)
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
