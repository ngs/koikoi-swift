import KoikoiAI
import KoikoiCore
import SwiftUI

/// 対局画面。上から相手陣・場・自陣の三段構成（全プラットフォーム共有）。
/// 操作系: タップ / ドラッグ&ドロップ（手札→場）/ 十字キー + Enter・Esc。
public struct GameView: View {
    @State private var model: GameViewModel
    @FocusState private var boardFocused: Bool
    /// 札の獲得アニメーション用（ゾーン間の移動を matchedGeometryEffect で結ぶ）。
    @Namespace private var cardSpace
    private let onExit: (() -> Void)?
    /// 札タイルの基準幅（= 下限。iPhone や狭いウィンドウではこの幅で折り返す）。
    static let cardTileWidth: CGFloat = 64
    /// 札タイルの上限幅（iPad 13 インチや広い macOS ウィンドウでの拡大上限）。
    static let maxCardTileWidth: CGFloat = 112
    /// 盤面の外周パディング。visionOS はウィンドウの角丸に食い込まないよう広めに取る。
    static let boardPadding: CGFloat = {
        #if os(visionOS)
        return 32
        #else
        return 12
        #endif
    }()
    /// 手札/場札 8 枚が 1 行に収まる幅（8×64 + 7×8 スペーシング + 左右パディング）。
    static let minBoardWidth: CGFloat = cardTileWidth * 8 + 8 * 7 + boardPadding * 2
    private static var macMinBoardWidth: CGFloat? {
        #if os(macOS)
        return minBoardWidth
        #else
        return nil
        #endif
    }

    /// 盤面幅から札タイル幅を決める。
    /// 手札/場札 8 枚 + 7 スペーシングが 1 行に収まる最大幅を取り、64…112pt に丸める
    /// （iPhone は常に下限 64 になり、従来どおりグリッドが折り返す）。
    static func tileWidth(forBoardWidth width: CGFloat) -> CGFloat {
        guard width > 0 else { return cardTileWidth }
        let available = width - boardPadding * 2 - 8 * 7
        return min(max(available / 8, cardTileWidth), maxCardTileWidth)
    }

    /// D&D の受け皿を張るか。ImageRenderer はドロップ受けのバッキングビューを
    /// 描画できず禁止マークのプレースホルダになるため、スナップショット描画時のみ
    /// false にする（実アプリでは常に true）。
    private let dropTargetsEnabled: Bool

    #if os(iOS)
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass
    /// iPhone 縦のように幅が狭い環境（右上のスコアボードと場所を取り合う）。
    private var isCompactWidth: Bool { horizontalSizeClass == .compact }
    #else
    private var isCompactWidth: Bool { false }
    #endif

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
        // 盤面幅から札の大きさを決める（iPad 13 インチや広い macOS ウィンドウで拡大する）
        GeometryReader { proxy in
            board(tile: Self.tileWidth(forBoardWidth: proxy.size.width))
        }
        // 場札・手札 8 枚が 1 行に収まる最小幅（ウィンドウをリサイズできる macOS のみ。
        // iPhone では画面幅を超えて盤面がはみ出すため、グリッドの折り返しに任せる）
        .frame(minWidth: Self.macMinBoardWidth)
        .overlay(alignment: .topTrailing) {
            ScoreboardPanel(
                monthName: Month(rawValue: (model.game.round - 1) % 12)?.localizedMonthName ?? "",
                round: model.game.round,
                maxRounds: model.game.maxRounds,
                playerScore: model.game.score(for: .player),
                opponentScore: model.game.score(for: .opponent))
            .padding(Self.boardPadding)
        }
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

    private func board(tile: CGFloat) -> some View {
        ZStack {
            #if os(visionOS)
            // visionOS はウィンドウのガラスをそのまま透過させる（緑ベタは敷かない）
            Color.clear
            #else
            Color.koikoiTable
                .ignoresSafeArea()
            #endif
            // 相手陣は上端・自陣は下端に固定し、山札・場札はセンターに置く
            // （ウィンドウを広げた分は手札とフィールドの間に入る）
            VStack(alignment: .leading, spacing: 12) {
                opponentArea(tile: tile).layoutPriority(1)
                Spacer(minLength: 0)
                fieldArea(tile: tile).layoutPriority(1)
                Spacer(minLength: 0)
                playerArea(tile: tile).layoutPriority(1)
            }
            .padding(Self.boardPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func opponentArea(tile: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // 幅が狭いときは裏札を小さく重ねて並べ、右上のスコアボードに潜り込ませない
            HStack(spacing: isCompactWidth ? -9 : 8) {
                ForEach(0..<model.game.hand(for: .opponent).count, id: \.self) { _ in
                    CardBack()
                        .frame(width: isCompactWidth ? 26 : tile * 0.53)
                }
                Spacer()
            }
            YakuBadges(yakus: model.opponentYaku)
            CapturedDetail(
                cards: model.game.captured(for: .opponent), cardWidth: tile * 0.47)
        }
    }

    private func fieldArea(tile: CGFloat) -> some View {
        VStack(spacing: 8) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: tile, maximum: tile), spacing: 8)],
                spacing: 8
            ) {
                ForEach(Array(model.game.field.enumerated()), id: \.element.id) { index, card in
                    ZStack(alignment: .topTrailing) {
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
                        .matchedGeometryEffect(id: card.id, in: cardSpace)
                        // がっちゃんこ中: 移動札を対象の場札に重ねて表示。
                        // タップ/キー操作は元の位置から飛ばし、D&D はドロップ位置に出現
                        if let animation = model.captureAnimation, animation.target == card {
                            if animation.fliesFromSource {
                                CardImage(animation.movingCard)
                                    .frame(width: tile * 0.9)
                                    .matchedGeometryEffect(
                                        id: animation.movingCard.id, in: cardSpace)
                                    .offset(x: 8, y: -8)
                                    .lifted(26)  // visionOS: 空中を飛んで重なる
                                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                            } else {
                                CardImage(animation.movingCard)
                                    .frame(width: tile * 0.9)
                                    .offset(x: 8, y: -8)
                                    .lifted(26)
                                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                            }
                        }
                    }
                    .zIndex(model.captureAnimation?.target == card ? 1 : 0)
                }
            }
            .background {
                // 空きへの捨て札ドロップ受け（透明）
                cardDropTarget(Color.clear.contentShape(Rectangle()), on: nil)
            }
            HStack(spacing: 12) {
                DeckStack(remaining: model.game.deck.count, cardWidth: tile * 0.62)
                if let drawn = model.drawnCard, model.captureAnimation?.movingCard != drawn {
                    HStack(spacing: 4) {
                        Text("Drawn:", bundle: .module)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        CardImage(drawn)
                            .frame(width: tile * 0.47)
                            .matchedGeometryEffect(id: drawn.id, in: cardSpace)
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
                Text("Choose a card from your hand", bundle: .module)
            case .selectField:
                Text("Choose a field card to take (Esc to cancel)", bundle: .module)
            case .opponentTurn:
                Text("Opponent's turn…", bundle: .module)
            case .decideKoikoi, .roundEnd, .matchEnd:
                Text("")
            }
        }
        .font(.caption)
        .foregroundStyle(.yellow)
    }

    private func playerArea(tile: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            YakuBadges(yakus: model.playerYaku)
            HStack(alignment: .bottom, spacing: 12) {
                CapturedDetail(
                    cards: model.game.captured(for: .player), cardWidth: tile * 0.47)
                Spacer(minLength: 0)
                // リーチは右側に寄せて獲得札と分離する
                if !model.playerReaches.isEmpty {
                    ReachList(reaches: model.playerReaches)
                }
            }
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: tile, maximum: tile), spacing: 8)],
                spacing: 8
            ) {
                // がっちゃんこ中の札は手札からは消し、場札側で描画する
                ForEach(
                    Array(model.game.hand(for: .player).enumerated())
                        .filter { $0.element != model.captureAnimation?.movingCard },
                    id: \.element.id
                ) { index, card in
                    HandCardView(
                        card: card,
                        matchCount: model.game.matchingFieldCards(for: card).count,
                        selected: model.pendingHandCard == card,
                        focused: model.cursor == .hand(index),
                        tappable: model.prompt == .selectHand || model.pendingHandCard != nil
                    ) {
                        model.tapHandCard(card)
                    }
                    .matchedGeometryEffect(id: card.id, in: cardSpace)
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
                Text("Yaku!", bundle: .module).font(.title2.bold())
                ForEach(newYaku, id: \.self) { yaku in
                    Text(verbatim: yaku.localizedSummary)
                }
                HStack(spacing: 16) {
                    Button(String(localized: "Koi-Koi!", bundle: .module)) {
                        model.decide(koikoi: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .overlay { dialogFocusRing(when: model.dialogKoikoiSelected) }
                    Button(String(localized: "Stop", bundle: .module)) {
                        model.decide(koikoi: false)
                    }
                    .buttonStyle(.bordered)
                    .overlay { dialogFocusRing(when: !model.dialogKoikoiSelected) }
                }
            }
        case .roundEnd(let outcome):
            dialog {
                Text(verbatim: KoikoiText.roundEndTitle(winner: outcome.winner))
                    .font(.title2.bold())
                if outcome.winner != nil {
                    Text(verbatim: KoikoiText.points(outcome.points))
                }
                Button(String(localized: "Next", bundle: .module)) {
                    model.proceedAfterRound()
                }
                .buttonStyle(.borderedProminent)
            }
        case .matchEnd(let winner):
            dialog {
                Text(verbatim: KoikoiText.matchEndTitle(winner: winner)).font(.title.bold())
                Text(
                    verbatim: KoikoiText.finalScore(
                        player: model.game.score(for: .player),
                        opponent: model.game.score(for: .opponent)))
                if let onExit {
                    Button(String(localized: "Back to Title", bundle: .module)) { onExit() }
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
        .lifted(48)  // visionOS: ダイアログは盤の手前に浮かべる
    }
}

#Preview("Game Board") {
    GameView(model: GameViewModel(rounds: 3, difficulty: .normal, seed: 42))
}
