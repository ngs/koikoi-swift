import GameController
import KoikoiAI
import KoikoiCore
import SwiftUI

/// 三列レイアウト（左右に陣営、中央に場と手札）の寸法。
/// 横向き iPhone と macOS で札や列の大きさが違うため、値をまとめて渡す。
public struct WideLayoutMetrics: Sendable {
    /// 左右の列の幅。
    public let sideColumnWidth: CGFloat
    /// 獲得札サムネイルの幅。
    public let thumbnail: CGFloat
    /// 3 カラム間のスペーシング。
    public let columnSpacing: CGFloat
    /// 相手の裏札の幅と重ね幅。
    public let backWidth: CGFloat
    public let backSpacing: CGFloat
    /// 盤面の外周パディング。
    public let horizontalPadding: CGFloat
    public let verticalPadding: CGFloat

    /// サムネイル同士の間隔（全プラットフォーム共通）。
    public static let thumbnailSpacing: CGFloat = 2

    /// 横向き iPhone。左右はセーフエリアの内側ぎりぎりまで使う。
    /// サムネイル 4 枚（4×30 + 3×2 = 126pt）が 1 行に収まる列幅。
    public static let phone = WideLayoutMetrics(
        sideColumnWidth: 128, thumbnail: 30, columnSpacing: 12,
        backWidth: 20, backSpacing: -7,
        horizontalPadding: 0, verticalPadding: 12)

    /// macOS。ウィンドウには余裕があるので列も札も一回り大きくする。
    public static let mac = WideLayoutMetrics(
        sideColumnWidth: 176, thumbnail: 40, columnSpacing: 16,
        backWidth: 28, backSpacing: -9,
        horizontalPadding: 16, verticalPadding: 16)
}

/// 対局画面。上から相手陣・場・自陣の三段構成（全プラットフォーム共有）。
/// 操作系: タップ / ドラッグ&ドロップ（手札→場）/ 十字キー + Enter・Esc。
public struct GameView: View {
    @State private var model: GameViewModel
    @FocusState private var boardFocused: Bool
    /// ハードウェアキーボードの有無。キーボードカーソルの枠はキーボードがある時だけ描く。
    /// macOS は常にキーボードがあるものとし、iOS / visionOS は GCKeyboard の接続で判定する。
    @State private var hasKeyboard = Self.keyboardIsConnected
    private static var keyboardIsConnected: Bool {
        #if os(macOS)
        return true
        #else
        return GCKeyboard.coalesced != nil
        #endif
    }
    @Environment(\.koikoiPalette)
    private var palette
    /// 背景を透過するか（対局設定画面のトグルと共有する）。
    @AppStorage(KoikoiAppearance.translucencyStorageKey)
    private var translucentWindow = KoikoiAppearance.defaultTranslucency
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
    /// 三列レイアウトでウィンドウを縮められる下限の札幅。
    /// これより狭いと札が読みづらくなるので、ウィンドウのリサイズ下限に使う
    /// （札そのものは横向き iPhone と同じく 40pt まで縮む）。
    static let minWideTileWidth: CGFloat = 48

    /// 三列レイアウトで、左右の列と山札を置いたうえで札 8 枚が
    /// `minWideTileWidth` に収まる最小のウィンドウ幅（macOS のリサイズ下限）。
    static var wideMinBoardWidth: CGFloat {
        let metrics = wideMetrics
        let deck = minWideTileWidth * 0.62 + 12
        return metrics.horizontalPadding * 2
            + 2 * (metrics.sideColumnWidth + metrics.columnSpacing)
            + deck + minWideTileWidth * 8 + gridSpacing(compact: true) * 7
    }
    private static var macMinBoardWidth: CGFloat? {
        #if os(macOS)
        return wideMinBoardWidth
        #else
        return nil
        #endif
    }

    /// compact 幅（iPhone 縦）での札タイル幅の下限。
    static let minCompactTileWidth: CGFloat = 40

    /// 三列レイアウトの寸法（横向き iPhone と macOS で値が違う）。
    static var wideMetrics: WideLayoutMetrics {
        #if os(macOS)
        return .mac
        #else
        return .phone
        #endif
    }

    /// 与えた幅に収まるサムネイルの列数（LazyVGrid の adaptive と同じ数え方）。
    static func capturedColumns(
        forWidth width: CGFloat,
        thumbnail: CGFloat,
        spacing: CGFloat = WideLayoutMetrics.thumbnailSpacing
    ) -> Int {
        max(Int(floor((width + spacing) / (thumbnail + spacing))), 1)
    }

    /// グリッドのスペーシング（compact 幅では詰めて 8 枚を 1 行に収める）。
    static func gridSpacing(compact: Bool) -> CGFloat {
        compact ? 4 : 8
    }

    /// 盤面幅から札タイル幅を決める。
    /// 手札/場札 8 枚 + 7 スペーシングが 1 行に収まる最大幅を取り、64…112pt に丸める。
    /// compact 幅（iPhone 縦）では折り返すと縦が足りないため、
    /// 8 枚が 1 行に収まるよう 64pt 未満（下限 40pt）まで縮める。
    static func tileWidth(forBoardWidth width: CGFloat, compact: Bool = false) -> CGFloat {
        guard width > 0 else { return compact ? minCompactTileWidth : cardTileWidth }
        let available = width - boardPadding * 2 - gridSpacing(compact: compact) * 7
        if compact {
            return min(max(floor(available / 8), minCompactTileWidth), cardTileWidth)
        }
        return min(max(available / 8, cardTileWidth), maxCardTileWidth)
    }

    /// 三列レイアウト: 左右の列を除いた中央幅と、盤面の高さの両方から札幅を決める。
    /// 中央の列は場札（最大 2 行に折り返す）+ 手札 1 行 = 3 行分の高さを要する。
    static func wideTileWidth(metrics: WideLayoutMetrics, forBoardSize size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return minCompactTileWidth }
        let spacing = gridSpacing(compact: true)
        let centerWidth =
            size.width - metrics.horizontalPadding * 2
            - 2 * (metrics.sideColumnWidth + metrics.columnSpacing)
        // 場札の横には山札（tile * 0.62 + 間隔 12pt）が並ぶので、その分も幅から解く
        let widthBased = floor((centerWidth - 12 - spacing * 7) / (8 + 0.62))
        // 外周パディング・ステータス行（約 20pt）・グリッド間隔・VStack のスペーシングを引く
        // （スコアボードはツールバーにあるので盤面の高さは使わない）
        let availableHeight =
            size.height - metrics.verticalPadding * 2 - 20 - spacing * 2 - 8 * 2
        let heightBased = floor(((availableHeight - spacing * 2) / 3) * Card.aspectRatio)
        return min(max(min(widthBased, heightBased), minCompactTileWidth), maxCardTileWidth)
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
    @Environment(\.verticalSizeClass)
    private var verticalSizeClass
    /// 横向き iPhone（縦が足りず、上下三段の積み上げが入らない）。
    private var isLandscapePhone: Bool { verticalSizeClass == .compact }
    #else
    private var isCompactWidth: Bool { false }
    private var isLandscapePhone: Bool { false }
    #endif

    /// 三列レイアウト（左右に陣営、中央に場と手札）を使うか。
    /// macOS は常に、iOS は横向き iPhone のときだけ。visionOS は空間ボードを使う。
    private var usesWideLayout: Bool {
        #if os(macOS)
        return true
        #else
        return isLandscapePhone
        #endif
    }

    /// この環境の三列レイアウトの寸法。
    private var metrics: WideLayoutMetrics { Self.wideMetrics }

    /// 背景を透過する設定（macOS / visionOS でのみ選べる）。
    private var usesTranslucentWindow: Bool {
        KoikoiAppearance.isAvailable && translucentWindow
    }

    /// グリッドを詰めて 8 枚を 1 行に収める必要がある環境（狭い幅、または三列レイアウト）。
    private var usesCompactSpacing: Bool { isCompactWidth || usesWideLayout }

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
            board(
                tile: usesWideLayout
                    ? Self.wideTileWidth(metrics: metrics, forBoardSize: proxy.size)
                    : Self.tileWidth(forBoardWidth: proxy.size.width, compact: isCompactWidth),
                insets: proxy.safeAreaInsets)
        }
        // 場札・手札 8 枚が 1 行に収まる最小幅（ウィンドウをリサイズできる macOS のみ。
        // iPhone では画面幅を超えて盤面がはみ出すため、グリッドの折り返しに任せる）
        .frame(minWidth: Self.macMinBoardWidth)
        .overlay(alignment: .topTrailing) {
            // 幅が狭いときは相手陣の行に、横向きのときは右カラムに組み込む
            if !isCompactWidth && !usesWideLayout {
                scoreboard.padding(Self.boardPadding)
            }
        }
        .overlay { overlays }
        .animation(.default, value: model.game.field)
        .animation(.default, value: model.game.hands)
        .focusable()
        .focusEffectDisabled()
        .focused($boardFocused)
        .onAppear { boardFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .GCKeyboardDidConnect)) { _ in
            hasKeyboard = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCKeyboardDidDisconnect)) { _ in
            hasKeyboard = Self.keyboardIsConnected
        }
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

    private func board(tile: CGFloat, insets: EdgeInsets) -> some View {
        ZStack {
            tableBackground
            if usesWideLayout {
                wideBoard(tile: tile, insets: insets)
            } else {
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
                // 札が上限サイズに達した後は盤面を広げず中央に寄せる
                .frame(maxWidth: Self.boardWidth(forTile: tile, compact: isCompactWidth))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 盤面の地。透過が有効なときはウィンドウのマテリアルを活かす
    /// （カタログのテーマだけ、色が分かるようにごく薄く重ねる）。
    @ViewBuilder private var tableBackground: some View {
        if usesTranslucentWindow {
            if palette.usesSystemColors {
                Color.clear
            } else {
                palette.table
                    .opacity(KoikoiAppearance.tintOpacity)
                    .ignoresSafeArea()
            }
        } else {
            palette.table
                .ignoresSafeArea()
        }
    }

    // MARK: - 三列レイアウト（横向き iPhone / macOS）

    /// 三列レイアウト: 自分の情報（左）・場と手札（中央）・相手情報（右）。
    private func wideBoard(tile: CGFloat, insets: EdgeInsets) -> some View {
        HStack(alignment: .top, spacing: metrics.columnSpacing) {
            // 他の花札ゲームやスコアボードの並び（You | Opponent）に合わせ、自分を左に置く
            // 幅の固定だけで足りる（横のはみ出しは ScrollView 自身が切る）
            widePlayerColumn(insets: insets)
                .frame(width: metrics.sideColumnWidth, alignment: .leading)
            wideCenterColumn(tile: tile)
                .frame(maxWidth: .infinity)
                // 中央で動く札が側方カラムに隠れないようにする
                .zIndex(1)
            wideOpponentColumn(insets: insets)
                .frame(width: metrics.sideColumnWidth, alignment: .leading)
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.vertical, metrics.verticalPadding)
        // 列の中身が伸びても盤面の高さを超えない（手札が画面外に押し出されるのを防ぐ）
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func wideOpponentColumn(insets: EdgeInsets) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // 獲得札が増えても列が伸びて中央の手札を押し出さないようスクロールに収める
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    // 影は 1 枚ごとではなく列全体に 1 つ落とす（重ねたとき縁が黒ずまない）
                    HStack(spacing: metrics.backSpacing) {
                        ForEach(0..<model.game.hand(for: .opponent).count, id: \.self) { _ in
                            CardBack(shadowed: false)
                                // 高さは比率から確定させる
                                // （縦の提案に委ねると 0 に潰れて裏札が消える）
                                .frame(
                                    width: metrics.backWidth,
                                    height: metrics.backWidth / Card.aspectRatio)
                        }
                    }
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                    YakuBadges(yakus: model.opponentYaku, stacked: true)
                    CapturedDetail(
                        cards: model.game.captured(for: .opponent),
                        cardWidth: metrics.thumbnail, axis: .vertical,
                        columns: Self.capturedColumns(
                            forWidth: metrics.sideColumnWidth, thumbnail: metrics.thumbnail))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .modifier(sideColumnScroll(insets: insets))
        }
    }

    /// 側方カラムのスクロール設定（画面端まで広げ、同じ量を内容の余白に戻す）。
    private func sideColumnScroll(insets: EdgeInsets) -> SideColumnScroll {
        SideColumnScroll(
            topMargin: insets.top + metrics.verticalPadding,
            bottomMargin: insets.bottom + metrics.verticalPadding)
    }

    private func wideCenterColumn(tile: CGFloat) -> some View {
        // 8 枚 + スペーシングの行幅（場札・手札とも中央に寄せる）
        let rowWidth = tile * 8 + Self.gridSpacing(compact: true) * 7
        return VStack(spacing: 8) {
            Spacer(minLength: 0)
            // 場と山札は横に並べ、残りの空間の中央に置く
            HStack(alignment: .center, spacing: 12) {
                DeckStack(remaining: model.game.deck.count, cardWidth: tile * 0.62)
                fieldGrid(tile: tile)
                    .frame(width: rowWidth)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                drawnPreview(tile: tile)
                Spacer(minLength: 0)
                statusText
            }
            handGrid(tile: tile)
                .frame(width: rowWidth)
                .frame(maxWidth: .infinity)
        }
    }

    private func widePlayerColumn(insets: EdgeInsets) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                YakuBadges(yakus: model.playerYaku, stacked: true)
                CapturedDetail(
                    cards: model.game.captured(for: .player),
                    cardWidth: metrics.thumbnail, axis: .vertical,
                    columns: Self.capturedColumns(
                            forWidth: metrics.sideColumnWidth, thumbnail: metrics.thumbnail))
                if !model.playerReaches.isEmpty {
                    ReachList(reaches: model.playerReaches, wraps: true)
                        .padding(.top, 10)  // 獲得札との間を空ける
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .modifier(sideColumnScroll(insets: insets))
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

    private var scoreboard: some View { GameScoreboard(model: model) }

    /// 8 枚 + スペーシング + 外周パディングの盤面幅。
    static func boardWidth(forTile tile: CGFloat, compact: Bool = false) -> CGFloat {
        tile * 8 + gridSpacing(compact: compact) * 7 + boardPadding * 2
    }

    /// 獲得札サムネイルの幅（compact では札が小さいので下限を設ける）。
    private func capturedWidth(tile: CGFloat) -> CGFloat {
        max(tile * 0.47, 30)
    }

    private func opponentArea(tile: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // 幅が狭いときは裏札を小さく重ねて並べ、同じ行の右端にスコアボードを置く
            HStack(alignment: .top, spacing: isCompactWidth ? -9 : 8) {
                // 影は 1 枚ごとではなく列全体に 1 つ落とす（重ねたとき縁が黒ずまない）
                HStack(spacing: isCompactWidth ? -9 : 8) {
                    ForEach(0..<model.game.hand(for: .opponent).count, id: \.self) { _ in
                        CardBack(shadowed: false)
                            .frame(width: isCompactWidth ? 26 : tile * 0.53)
                    }
                }
                .compositingGroup()
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                Spacer()
                if isCompactWidth {
                    scoreboard
                }
            }
            YakuBadges(yakus: model.opponentYaku)
            CapturedDetail(
                cards: model.game.captured(for: .opponent), cardWidth: capturedWidth(tile: tile))
        }
    }

    private func fieldArea(tile: CGFloat) -> some View {
        VStack(spacing: 8) {
            fieldGrid(tile: tile)
            HStack(spacing: 12) {
                DeckStack(remaining: model.game.deck.count, cardWidth: tile * 0.62)
                drawnPreview(tile: tile)
                Spacer()
                statusText
            }
        }
    }

    /// 場札のグリッド（縦レイアウト・横向きレイアウトで共有する）。
    private func fieldGrid(tile: CGFloat) -> some View {
        Group {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: tile, maximum: tile),
                        spacing: Self.gridSpacing(compact: usesCompactSpacing))
                ],
                spacing: Self.gridSpacing(compact: usesCompactSpacing)
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
                        // がっちゃんこ中の移動札を置く位置。札そのものはグリッドの
                        // オーバーレイに描くので、ここには透明のアンカーだけを残す
                        // （LazyVGrid は macOS で zIndex を尊重せず、グリッド項目の中に
                        // 描くと詰め直される隣の札に潜り込んでしまう）
                        if let animation = model.captureAnimation, animation.target == card {
                            Color.clear
                                .frame(width: tile, height: tile / Card.aspectRatio)
                                .matchedGeometryEffect(
                                    id: Self.captureAnchorID, in: cardSpace, isSource: true)
                        }
                    }
                    // 移動中・獲得直後の札は、詰め直される隣の札より前面に置く
                    // （iOS ではこれで十分。macOS の LazyVGrid は zIndex を無視する）
                    .zIndex(raisesAboveField(card) ? 1 : 0)
                    // 獲得された札は飛来アニメーションの直後に即消す。フェードで残ると
                    // 詰め直される隣の札にかぶられて「下をくぐる」ように見える
                    .transition(.identity)
                }
            }
            .background {
                // 空きへの捨て札ドロップ受け（透明）
                cardDropTarget(Color.clear.contentShape(Rectangle()), on: nil)
            }
            // 移動札はグリッドの外側に描き、どの場札よりも確実に前面に置く
            .overlay { flyingCard(tile: tile) }
        }
    }

    /// がっちゃんこ中の移動札を置くアンカーの ID（札の ID = Int とは衝突しない）。
    private static let captureAnchorID = "capture-target"

    /// がっちゃんこ中の移動札。対象の場札に重なる位置に描く。
    /// タップ/キー操作は元の位置から飛ばし、D&D はドロップ位置に出現する。
    @ViewBuilder
    private func flyingCard(tile: CGFloat) -> some View {
        if let animation = model.captureAnimation {
            Group {
                if animation.fliesFromSource {
                    CardImage(animation.movingCard)
                        .frame(width: tile * 0.9)
                        .matchedGeometryEffect(id: animation.movingCard.id, in: cardSpace)
                } else {
                    CardImage(animation.movingCard)
                        .frame(width: tile * 0.9)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .offset(x: 8, y: -8)
            .lifted(26)  // visionOS: 空中を飛んで重なる
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            .matchedGeometryEffect(
                id: Self.captureAnchorID, in: cardSpace,
                properties: .position, isSource: false)
        }
    }

    /// この場札を隣より前面に描くか（移動中・対象・直前に取られた札）。
    private func raisesAboveField(_ card: Card) -> Bool {
        if let animation = model.captureAnimation {
            if animation.target == card || animation.movingCard == card { return true }
        }
        return model.lastCapturedIDs.contains(card.id)
    }

    /// 山札から引いた札のプレビュー。
    @ViewBuilder
    private func drawnPreview(tile: CGFloat) -> some View {
        if let drawn = model.drawnCard, model.captureAnimation?.movingCard != drawn {
            HStack(spacing: 4) {
                Text("Drawn:", bundle: .module)
                    .font(.caption)
                    .foregroundStyle(palette.ink.opacity(0.8))
                CardImage(drawn)
                    .frame(width: capturedWidth(tile: tile))
                    .matchedGeometryEffect(id: drawn.id, in: cardSpace)
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
                EmptyView()
            }
        }
        .font(.caption)
        .foregroundStyle(palette.highlight)
    }

    private func playerArea(tile: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            YakuBadges(yakus: model.playerYaku)
            if isCompactWidth {
                // 幅が狭いときはリーチを獲得札の下に置く（横並びだと獲得札を隠す）
                CapturedDetail(
                    cards: model.game.captured(for: .player), cardWidth: capturedWidth(tile: tile))
                if !model.playerReaches.isEmpty {
                    ReachList(reaches: model.playerReaches)
                }
            } else {
                HStack(alignment: .bottom, spacing: 12) {
                    CapturedDetail(
                        cards: model.game.captured(for: .player), cardWidth: capturedWidth(tile: tile))
                    Spacer(minLength: 0)
                    // リーチは右側に寄せて獲得札と分離する
                    if !model.playerReaches.isEmpty {
                        ReachList(reaches: model.playerReaches)
                    }
                }
            }
            handGrid(tile: tile)
        }
    }

    /// 自分の手札のグリッド（縦レイアウト・横向きレイアウトで共有する）。
    private func handGrid(tile: CGFloat) -> some View {
        Group {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: tile, maximum: tile),
                        spacing: Self.gridSpacing(compact: usesCompactSpacing))
                ],
                spacing: Self.gridSpacing(compact: usesCompactSpacing)
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

    /// ダイアログのキーボードカーソル。キーボード非接続時（iPhone のタッチ操作）は描かない。
    private func dialogFocusRing(when selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(palette.highlight, lineWidth: selected && hasKeyboard ? 3 : 0)
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
