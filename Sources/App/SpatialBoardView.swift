#if os(visionOS)
import KoikoiAI
import KoikoiCore
import KoikoiUI
import RealityKit
import SwiftUI
import UniformTypeIdentifiers

/// 空間ボードの寸法（すべてメートル。札は実物の花札とほぼ同じ大きさ）。
/// 盤面のエンティティと SwiftUI の attachment が同じ座標系を共有するため、
/// 位置はここに一元化する。
enum SpatialLayout {
    static let cardWidth: Float = 0.057
    static let cardHeight: Float = 0.087
    static let handPitch: Float = 0.065
    static let feltWidth: Float = 1.00
    static let feltDepth: Float = 0.86

    /// 山札（場の左）。
    static let deckX: Float = -0.36
    static let deckZ: Float = 0.02
    static let deckTop: SIMD3<Float> = [deckX, 0.06, deckZ]

    /// 場札の先頭行の奥行きと、行送り。
    static let fieldZ: Float = -0.05
    static let fieldRowPitch: Float = 0.10

    /// 自分の手札は卓から 80 度起こし、手前の縁の上に浮かべる（持ち札のように立てる）。
    static let handTilt: Float = 80 * .pi / 180
    static let handZ: Float = 0.35
    static var handY: Float { cardHeight / 2 * sin(handTilt) + 0.006 }

    /// 相手の裏札（奥の縁）。
    static let opponentHandZ: Float = -0.33
    static let opponentHandSpot: SIMD3<Float> = [0, 0.02, opponentHandZ]

    /// 獲得札のパネル（卓に伏せる attachment）と、そこへ飛ぶ札の落とし所。
    static let capturedPlayer: SIMD3<Float> = [0.02, capturedPanelY, 0.13]
    static let capturedOpponent: SIMD3<Float> = [0.02, capturedPanelY, -0.20]
    /// 伏せたパネルの向き。X 軸まわりに -60 度で、真上から読めて手前に 30 度起きる
    /// （立てた手札越しでも文字が読めるよう、卓と垂直から少し起こす）。
    static let flatTilt: Float = -60 * .pi / 180
    /// パネルの中心の高さ。attachment の原点は中心なので、傾けたぶん下端が沈む
    /// （半分の高さ × cos(傾き)）。卓に潜って下端の角丸が隠れないよう、その分に
    /// 少し余裕を足して浮かせる。
    static var capturedPanelY: Float {
        let height = Float(capturedPanelHeight + capturedPanelPadding * 2) / pointsPerMeter
        return height / 2 * cos(flatTilt) + 0.004
    }

    /// 立てて浮かべるパネル（視線に正対するので回転は掛けない）。
    /// 役とリーチは卓の右、スコアボードは左に離して置く
    /// （どちらも左に置くと、手前のパネルが奥のパネルを隠してしまう）。
    static let yakuPlayer: SIMD3<Float> = [0.46, 0.20, 0.30]
    static let yakuOpponent: SIMD3<Float> = [0.46, 0.20, -0.32]
    static let scoreboard: SIMD3<Float> = [-0.60, 0.22, 0.14]
    /// ダイアログは立てた手札より手前・少し上に置く。
    static let dialog: SIMD3<Float> = [0, 0.28, 0.46]

    /// visionOS の attachment は 1360pt = 1m で描かれる。
    static let pointsPerMeter: Float = 1_360
    /// 卓に伏せる獲得札パネルの大きさ（pt）。
    static let capturedPanelWidth: CGFloat = 430
    static let capturedPanelHeight: CGFloat = 84
    static let capturedPanelPadding: CGFloat = 10
    static let capturedThumbnail: CGFloat = 34
}

/// RealityView の attachment の識別子（固定の集合にして出し入れで揺れないようにする）。
/// パネルの下に出る移動用バーの名前を `panel:<rawValue>` にして、
/// ドラッグ時にどのパネルかを引く。
private enum SpatialAttachment: String, CaseIterable {
    case capturedPlayer
    case capturedOpponent
    case yakuPlayer
    case yakuOpponent
    case scoreboard
    case dialog

    /// 既定のレイアウト位置。
    var defaultPosition: SIMD3<Float> {
        switch self {
        case .capturedPlayer: return SpatialLayout.capturedPlayer
        case .capturedOpponent: return SpatialLayout.capturedOpponent
        case .yakuPlayer: return SpatialLayout.yakuPlayer
        case .yakuOpponent: return SpatialLayout.yakuOpponent
        case .scoreboard: return SpatialLayout.scoreboard
        case .dialog: return SpatialLayout.dialog
        }
    }

    /// ユーザーが好きな場所へ動かせるパネルか（卓に伏せた獲得札とダイアログは固定）。
    var isDraggable: Bool {
        switch self {
        case .yakuPlayer, .yakuOpponent, .scoreboard: return true
        case .capturedPlayer, .capturedOpponent, .dialog: return false
        }
    }

    /// 掴んで動かすためのバー（パネル本体ではなくこれが入力を受ける）。
    var gripName: String { "panel:\(rawValue)" }

    static func named(_ entityName: String) -> SpatialAttachment? {
        guard entityName.hasPrefix("panel:") else { return nil }
        return SpatialAttachment(rawValue: String(entityName.dropFirst(6)))
    }
}

/// visionOS のメイン画面。AR 空間に実寸大のフェルト盤を水平に置き、俯瞰で花札を遊ぶ。
/// 情報表示（獲得札・役・リーチ・スコア）は 2D 版と同じ SwiftUI 部品を
/// attachment として卓の上に置き、札そのものは RealityKit のエンティティで動かす。
/// 札 1 枚 = 1 エンティティを使い回し、ゾーン間の移動は move(to:) の 3D アニメーションで表現する。
struct SpatialBoardView: View {
    @State private var model: GameViewModel?
    @State private var moves: [Move] = []
    @State private var importing = false
    @State private var board = BoardScene()
    /// 選択中の配色（対局設定パネルのピッカーと共有する）。
    @AppStorage(KoikoiTheme.storageKey)
    private var themeRaw = KoikoiTheme.felt.rawValue
    private var theme: KoikoiTheme { KoikoiDebugLaunch.theme(themeRaw) }
    /// フェルトを透かすか（対局設定パネルのトグルと共有する）。
    @AppStorage(KoikoiAppearance.translucencyStorageKey)
    private var translucentWindow = KoikoiAppearance.defaultTranslucency
    private var spatialColors: SpatialColors {
        SpatialColors(palette: KoikoiPalette(theme: theme), translucent: translucentWindow)
    }
    /// ユーザーがドラッグして動かしたパネルの位置（既定位置からのオフセット）。
    @State private var panelOffsets = SpatialPanelOffsets.load()
    private let store = GameStore.shared

    var body: some View {
        GeometryReader3D { proxy in
            RealityView { content, attachments in
                content.add(board.root)
                ground(content, proxy: proxy)
                board.apply(colors: spatialColors)
                board.sync(model: model, animated: false)
                place(attachments)
            } update: { content, attachments in
                ground(content, proxy: proxy)
                board.apply(colors: spatialColors)
                board.sync(model: model, animated: true)
                place(attachments)
            } attachments: {
                // 出し入れで attachment の集合が変わらないよう、
                // 中身が無いときは空のビューを返す（集合が動くと表示が不安定になる）
                Attachment(id: SpatialAttachment.capturedPlayer.rawValue) {
                    capturedPanel(for: .player)
                }
                Attachment(id: SpatialAttachment.capturedOpponent.rawValue) {
                    capturedPanel(for: .opponent)
                }
                Attachment(id: SpatialAttachment.yakuPlayer.rawValue) {
                    yakuPanel(side: .player)
                }
                Attachment(id: SpatialAttachment.yakuOpponent.rawValue) {
                    yakuPanel(side: .opponent)
                }
                Attachment(id: SpatialAttachment.scoreboard.rawValue) {
                    scoreboardPanel
                }
                Attachment(id: SpatialAttachment.dialog.rawValue) {
                    dialogPanel
                }
            }
            .gesture(boardGesture)
        }
        // 対局設定だけは ornament で出す（盤がまだ無いので卓に貼り付けられない）
        .ornament(attachmentAnchor: .scene(.back)) {
            if model == nil {
                setupPanel
            }
        }
        .onAppear {
            GameCenterService.shared.authenticate()
            // 起動時は保存済みの対局をそのまま復元する
            // （デバッグ用の局面が指定されていればそちらを優先し、保存はしない）
            if model == nil, let fixture = KoikoiDebugLaunch.fixture() {
                start(record: fixture, persists: false)
            } else if model == nil, let saved = store.load() {
                start(record: saved)
            }
        }
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.koikoiGame]
        ) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url),
                let record = try? JSONDecoder().decode(GameRecord.self, from: data) else { return }
            start(record: record)
        }
    }

    // MARK: - パネル（attachment の中身）

    private var setupPanel: some View {
        VStack(spacing: 20) {
            GameSetupView { rounds, difficulty in
                start(record: GameRecord(
                    rounds: rounds, difficulty: difficulty,
                    seed: UInt64.random(in: .min ... .max)))
            }
            Button(String(localized: "Open Saved Game"), systemImage: "folder") {
                importing = true
            }
            Button(
                String(localized: "Reset Panel Positions", bundle: .koikoiUI),
                systemImage: "arrow.counterclockwise"
            ) {
                panelOffsets = SpatialPanelOffsets()
                SpatialPanelOffsets.clear()
            }
            .disabled(panelOffsets.isEmpty)
        }
        .padding(24)
        .glassBackgroundEffect()
    }

    /// 卓に伏せる獲得札のパネル（2D 版の横並び `CapturedDetail` そのまま）。
    @ViewBuilder
    private func capturedPanel(for seat: Seat) -> some View {
        if let model, !model.game.captured(for: seat).isEmpty {
            CapturedDetail(
                cards: model.game.captured(for: seat),
                cardWidth: SpatialLayout.capturedThumbnail)
                .frame(
                    width: SpatialLayout.capturedPanelWidth,
                    height: SpatialLayout.capturedPanelHeight,
                    alignment: .leading)
                // 卓の色に関わらず種類のラベルが読めるよう、薄い盆を敷く
                .padding(SpatialLayout.capturedPanelPadding)
                .background(
                    .thinMaterial,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .koikoiTheme(theme)
        }
    }

    @ViewBuilder
    private func yakuPanel(side: BoardYakuPanel.Side) -> some View {
        if let model {
            BoardYakuPanel(model: model, side: side)
                .koikoiTheme(theme)
        }
    }

    @ViewBuilder private var scoreboardPanel: some View {
        if let model {
            ScoreboardStrip(model: model, onQuit: quitToTitle)
                .koikoiTheme(theme)
        }
    }

    /// 役成立・ラウンド終了・対局終了のダイアログ（立てた手札より手前に出す）。
    @ViewBuilder private var dialogPanel: some View {
        if let model {
            switch model.prompt {
            case .decideKoikoi(let newYaku):
                dialog {
                    Text("Yaku!", bundle: .koikoiUI).font(.title2.bold())
                    ForEach(newYaku, id: \.self) { yaku in
                        Text(verbatim: yaku.localizedSummary)
                    }
                    HStack(spacing: 16) {
                        Button(String(localized: "Koi-Koi!", bundle: .koikoiUI)) {
                            model.decide(koikoi: true)
                        }
                        .buttonStyle(.borderedProminent)
                        Button(String(localized: "Stop", bundle: .koikoiUI)) {
                            model.decide(koikoi: false)
                        }
                    }
                }
            case .roundEnd(let outcome):
                dialog {
                    Text(verbatim: KoikoiText.roundEndTitle(winner: outcome.winner))
                        .font(.title2.bold())
                    if outcome.winner != nil {
                        Text(verbatim: KoikoiText.points(outcome.points))
                    }
                    Button(String(localized: "Next", bundle: .koikoiUI)) {
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
                    Button(String(localized: "Back to Title", bundle: .koikoiUI), action: quitToTitle)
                        .buttonStyle(.borderedProminent)
                }
            case .selectHand, .selectField, .opponentTurn:
                EmptyView()
            }
        }
    }

    private func dialog(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .padding(24)
        .frame(minWidth: 280)
        .koikoiTheme(theme)
        .glassBackgroundEffect()
    }

    // MARK: - 対局セッション

    /// - Parameter persists: 指し手を保存へ書き戻すか
    ///   （デバッグ用の差し替え局面では書かない）。
    private func start(record: GameRecord, persists: Bool = true) {
        moves = record.moves
        // 2D 用の獲得アニメ演出（適用前ディレイ）は使わず、3D 側のタイムラインで表現する
        let model = GameViewModel(record: record, captureAnimationsEnabled: false)
        guard persists else {
            self.model = model
            return
        }
        store.save(record)
        model.onMoveApplied = { move in
            moves.append(move)
            store.save(
                GameRecord(
                    rounds: record.rounds, difficulty: record.difficulty,
                    seed: record.seed, moves: moves))
        }
        // 対局が終わった時点で保存を捨てる（結果表示中に kill されても復元しない）
        model.onMatchEnd = { _ in
            store.clear()
        }
        self.model = model
    }

    private func quitToTitle() {
        store.clear()
        model = nil
        moves = []
    }

    // MARK: - RealityView 補助

    /// ボードの原点を volume の底面に接地させる。
    private func ground(_ content: RealityViewContent, proxy: GeometryProxy3D) {
        let bounds = content.convert(proxy.frame(in: .local), from: .local, to: .scene)
        board.root.position.y = bounds.min.y
    }

    /// attachment のエンティティを盤の座標系に配置する（毎更新で位置を保つ）。
    /// 動かせるパネルは、保存されたオフセットを既定位置に足した場所に置く。
    private func place(_ attachments: RealityViewAttachments) {
        for panel in SpatialAttachment.allCases {
            board.place(
                attachments.entity(for: panel.rawValue),
                id: panel.rawValue,
                gripName: panel.isDraggable ? panel.gripName : nil,
                at: position(of: panel),
                tiltX: panel == .capturedPlayer || panel == .capturedOpponent
                    ? SpatialLayout.flatTilt : 0)
        }
    }

    /// パネルの現在位置（既定位置 + ユーザーが動かした分。ドラッグ中は掴んでいる場所）。
    private func position(of panel: SpatialAttachment) -> SIMD3<Float> {
        guard panel.isDraggable,
            let offset = board.liveOffsets[panel.rawValue] ?? panelOffsets[panel.rawValue]
        else { return panel.defaultPosition }
        return panel.defaultPosition + offset
    }

    /// パネルの床。卓（y = 0）より下には落とせない。
    private static let panelMinimumY: Float = 0.06

    /// 動いていないドラッグをタップとみなす距離（メートル）。
    private static let tapSlop = 0.02

    /// 盤面のジェスチャ。札のタップとパネルのドラッグを 1 本で捌く
    /// （TapGesture と DragGesture を別々に付けると、visionOS ではドラッグ側が
    /// 認識されず一度も発火しない）。
    ///
    /// ドラッグ中はエンティティを直接動かし、SwiftUI の状態は指を離したときだけ更新する
    /// （毎フレーム状態を書くと RealityView が作り直されてジェスチャが切れる）。
    private var boardGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .targetedToAnyEntity()
            .onChanged { value in
                guard let panel = SpatialAttachment.named(value.entity.name),
                    panel.isDraggable else { return }
                let offset = draggedOffset(panel, value: value)
                board.liveOffsets[panel.rawValue] = offset
                board.panels[panel.rawValue]?.position = panel.defaultPosition + offset
            }
            .onEnded { value in
                if let panel = SpatialAttachment.named(value.entity.name), panel.isDraggable {
                    let offset = draggedOffset(panel, value: value)
                    board.liveOffsets.removeValue(forKey: panel.rawValue)
                    board.dragOrigins.removeValue(forKey: panel.rawValue)
                    panelOffsets[panel.rawValue] = offset
                    panelOffsets.save()
                    return
                }
                let moved = value.translation3D
                let distance = (moved.x * moved.x + moved.y * moved.y + moved.z * moved.z)
                    .squareRoot()
                guard distance < Self.tapSlop else { return }
                handleTap(entityName: value.entity.name)
            }
    }

    /// ドラッグ中のパネルの、既定位置からのオフセット。
    private func draggedOffset(
        _ panel: SpatialAttachment, value: EntityTargetValue<DragGesture.Value>
    ) -> SIMD3<Float> {
        let origin = board.dragOrigins[panel.rawValue]
            ?? panelOffsets[panel.rawValue] ?? .zero
        board.dragOrigins[panel.rawValue] = origin
        let start = value.convert(value.startLocation3D, from: .local, to: board.root)
        let now = value.convert(value.location3D, from: .local, to: board.root)
        var offset = origin + (now - start)
        // 卓の面より下へは落とせない
        offset.y = max(offset.y, Self.panelMinimumY - panel.defaultPosition.y)
        return offset
    }

    private func handleTap(entityName: String) {
        guard let model, entityName.hasPrefix("card:"),
            let id = Int(entityName.dropFirst(5)),
            let card = Card.card(id: id) else { return }
        if model.game.hand(for: .player).contains(card) {
            model.tapHandCard(card)
        } else if model.game.field.contains(card) {
            model.tapFieldCard(card)
        }
    }
}

// MARK: - 盤面シーン

/// visionOS のマテリアル色（RealityKit は SwiftUI の Color を直接扱えないため UIColor にする）。
private struct SpatialColors: Equatable {
    let felt: UIColor
    let cardBack: UIColor
    let glow: UIColor
    /// フェルトの不透明度（透過が有効なら部屋が透ける）。札と山札は常に不透明。
    let feltOpacity: Float

    init(palette: KoikoiPalette, translucent: Bool) {
        felt = UIColor(palette.table)
        cardBack = UIColor(palette.cardBack)
        glow = UIColor(palette.highlight)
        feltOpacity = Float(KoikoiAppearance.tableOpacity(translucent: translucent))
    }

    /// フェルトのマテリアル。透過時はブレンドを有効にする
    /// （SimpleMaterial は色のアルファを反映しないため PBR を使う）。
    var feltMaterial: PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: felt)
        material.roughness = 1.0
        material.metallic = 0.0
        if feltOpacity < 1 {
            material.blending = .transparent(opacity: .init(floatLiteral: feltOpacity))
        }
        return material
    }
}

/// 盤面のエンティティを札 ID ごとに保持し、ビューモデルの状態へ差分同期するストア。
/// ゾーン遷移（手札→場→獲得、山札からの出現）を分類し、1 手ずつ時間差の
/// タイムラインに載せて move(to:) でアニメーションする。
/// 獲得済みの札は 3D では持たず、獲得パネル（attachment）に引き継ぐため、
/// 飛来アニメーションが終わったところでエンティティを引き上げる。
@MainActor
private final class BoardScene {
    let root = Entity()

    private var cards: [Int: ModelEntity] = [:]
    private var backs: [ModelEntity] = []
    private var felt: ModelEntity?
    private var deck: ModelEntity?
    private var deckRemaining = -1
    /// 前回同期時の各札の所在（手番シーケンスの再構成に使う）。
    private var zones: [Int: Zone] = [:]
    /// 前回適用した最終トランスフォーム（変化のない札の進行中アニメを守る）。
    private var targets: [Int: Transform] = [:]
    /// 札ごとの予約世代。新しい予約が入ったら古い遅延実行を無効化する。
    private var generations: [Int: Int] = [:]
    /// 獲得パネルへ飛んでいる最中で、着地後に消される札。
    private var retiring: Set<Int> = []
    /// パネルごとに作った移動バーの大きさ（同じなら作り直さない）。
    private var grips: [String: SIMD3<Float>] = [:]
    /// パネル本体のエンティティ（ドラッグで動かす対象）。
    var panels: [String: Entity] = [:]
    /// ドラッグ中のパネルの位置（SwiftUI の状態を毎フレーム書かないための置き場）。
    var liveOffsets: [String: SIMD3<Float>] = [:]
    /// ドラッグ開始時のオフセット。
    var dragOrigins: [String: SIMD3<Float>] = [:]
    /// マテリアルの色（既定は緑羅紗。テーマ変更時に apply(colors:) で差し替える）。
    private var colors = SpatialColors(
        palette: KoikoiPalette(theme: .felt),
        translucent: KoikoiAppearance.defaultTranslucency)

    private enum Zone { case hand, field, captured, drawn }

    /// 札 1 枚の目標配置。
    private struct Pose {
        var position: SIMD3<Float>
        var tilt: Float = 0
        var scale: Float = 1
        var raised = false
        var glowing = false
        var hoverable = false
        /// 手札に出すマッチ枚数バッジ（0 なら非表示）。
        var badgeCount = 0
    }

    /// 1 手ずつ札の移動を時間差で予約するタイムライン。
    private struct Timeline {
        var legs: [Int: [(Double, Transform)]] = [:]
        var spawns: [Int: SIMD3<Float>] = [:]
        var consumed: Set<Int> = []
        var clock = 0.0
    }

    /// attachment のエンティティを盤に取り込み、指定の位置・傾きに保つ。
    /// `gripName` を渡したパネルには、下端に移動用のバーを付ける。
    func place(
        _ entity: Entity?, id: String, gripName: String?, at position: SIMD3<Float>,
        tiltX: Float = 0
    ) {
        guard let entity else { return }
        if entity.parent !== root {
            root.addChild(entity)
        }
        entity.name = "attachment:\(id)"
        entity.position = position
        entity.orientation = simd_quatf(angle: tiltX, axis: [1, 0, 0])
        panels[id] = entity
        guard let gripName else { return }
        updateGrip(on: entity, id: id, named: gripName)
    }

    /// パネルを掴んで動かすためのバー（visionOS のウィンドウバーに倣って下端に置く）。
    /// パネル本体に当たり判定を付けると中のボタンが押せなくなるため、別のエンティティにする。
    /// 中身が空のときはバーごと外す（掴めない板を残さない）。
    private func updateGrip(on entity: Entity, id: String, named name: String) {
        let bounds = entity.visualBounds(relativeTo: entity)
        let extents = bounds.extents
        let existing = entity.children.first { $0.name == name }
        guard extents.x > 0.005, extents.y > 0.005 else {
            existing?.removeFromParent()
            grips.removeValue(forKey: id)
            return
        }
        let size = SIMD3<Float>(max(extents.x * 0.34, 0.04), 0.008, 0.012)
        if let existing, let previous = grips[id], simd_distance(previous, size) < 0.002 {
            existing.position = [bounds.center.x, bounds.min.y - 0.016, bounds.center.z]
            return
        }
        existing?.removeFromParent()
        grips[id] = size
        let grip = ModelEntity(
            mesh: .generateBox(size: size, cornerRadius: 0.004),
            materials: [SimpleMaterial(color: .white, roughness: 0.6, isMetallic: false)])
        grip.name = name
        grip.position = [bounds.center.x, bounds.min.y - 0.016, bounds.center.z]
        grip.components.set(CollisionComponent(shapes: [.generateBox(size: size)], isStatic: true))
        grip.components.set(InputTargetComponent())
        grip.components.set(HoverEffectComponent())
        entity.addChild(grip)
    }

    func sync(model: GameViewModel?, animated: Bool) {
        makeFeltIfNeeded()
        guard let model else {
            resetBoard()
            return
        }

        let game = model.game
        var poses: [Int: Pose] = [:]
        var newZones: [Int: Zone] = [:]
        collectPoses(model: model, into: &poses, zones: &newZones)

        // 獲得札は 3D の札としては持たず、獲得パネルへ吸い込まれて消える。
        // ゾーンと着地点だけ記録し、獲得の瞬間の飛来アニメーションに使う。
        var finals = poses.mapValues { transform(for: $0) }
        for (seat, spot) in [
            (Seat.player, SpatialLayout.capturedPlayer),
            (Seat.opponent, SpatialLayout.capturedOpponent)
        ] {
            let landing = Transform(
                scale: .init(repeating: 0.45), rotation: .init(angle: 0, axis: [1, 0, 0]),
                translation: spot)
            for card in game.captured(for: seat) {
                newZones[card.id] = .captured
                finals[card.id] = landing
            }
        }

        let opponentTotal = game.hand(for: .opponent).count
        let opponentPlayed = opponentTotal < backs.count
        syncBacks(total: opponentTotal, animated: animated)
        syncDeck(remaining: game.deck.count)

        let oldZones = zones
        zones = newZones

        // 新規登場した札（山札から引かれた・相手の手元から出た・配り直し）
        let appears = finals.keys.filter { oldZones[$0] == nil && cards[$0] == nil }
        var timeline = Timeline()
        if animated && appears.count <= 4 {
            timeline = buildTimeline(
                finals: finals, oldZones: oldZones,
                appears: appears.sorted(), opponentPlayed: opponentPlayed)
        }
        apply(finals: finals, poses: poses, timeline: timeline, animated: animated)
    }

    // MARK: 配置計算

    private func collectPoses(
        model: GameViewModel, into poses: inout [Int: Pose], zones newZones: inout [Int: Zone]
    ) {
        let game = model.game
        // 手札選択中は「いずれかの手札で獲得できる場札」を光らせる
        // （2D 版のホバー起点ハイライトは視線情報が取れない visionOS では使えない）
        let capturable: Set<Int> = model.prompt == .selectHand
            ? Set(game.hand(for: .player)
                .flatMap { game.matchingFieldCards(for: $0) }.map(\.id))
            : []
        let candidates = Set(model.highlightedFieldCards.map(\.id))

        let field = game.field
        for (index, card) in field.enumerated() {
            let row = index / 8
            let rowTotal = min(field.count - row * 8, 8)
            let isCandidate = candidates.contains(card.id)
            poses[card.id] = Pose(
                position: [
                    rowX(index % 8, of: rowTotal), 0.003,
                    SpatialLayout.fieldZ + Float(row) * SpatialLayout.fieldRowPitch
                ],
                raised: isCandidate,
                glowing: isCandidate || capturable.contains(card.id),
                hoverable: isCandidate)
            newZones[card.id] = .field
        }

        // 自分の手札。卓から 80 度起こして手前の縁に浮かべる（手に持っているように見せる）
        let hand = game.hand(for: .player)
        let selecting = model.prompt == .selectHand
        for (index, card) in hand.enumerated() {
            poses[card.id] = Pose(
                position: [
                    rowX(index, of: hand.count), SpatialLayout.handY, SpatialLayout.handZ
                ],
                tilt: SpatialLayout.handTilt,
                raised: model.pendingHandCard == card,
                hoverable: selecting,
                badgeCount: selecting ? game.matchingFieldCards(for: card).count : 0)
            newZones[card.id] = .hand
        }

        // 山札から引いた札は山札の上に浮かべて提示
        if let drawn = model.drawnCard {
            poses[drawn.id] = Pose(
                position: [SpatialLayout.deckX, 0.07, SpatialLayout.deckZ], tilt: 0.55)
            newZones[drawn.id] = .drawn
        }
    }

    private func rowX(_ index: Int, of total: Int) -> Float {
        (Float(index) - Float(total - 1) / 2) * SpatialLayout.handPitch
    }

    private func transform(for pose: Pose) -> Transform {
        Transform(
            scale: .init(repeating: pose.scale),
            rotation: simd_quatf(angle: pose.tilt, axis: [1, 0, 0]),
            translation: pose.position + [0, pose.raised ? 0.016 : 0, 0])
    }

    // MARK: 手番シーケンスの組み立て

    private func buildTimeline(
        finals: [Int: Transform], oldZones: [Int: Zone], appears: [Int], opponentPlayed: Bool
    ) -> Timeline {
        var timeline = Timeline()
        let fieldToCaptured = finals.keys.filter {
            oldZones[$0] == .field && zones[$0] == .captured
        }

        // 1. 自分の手札から出した札
        for id in finals.keys.sorted()
        where oldZones[id] == .hand && zones[id] != .hand {
            plan(id, into: &timeline, finals: finals, fieldToCaptured: fieldToCaptured)
        }
        // 2. 相手の手元から出た札（裏札が減ったときの出現札。獲得ペアのある札を優先）
        var deckAppears = appears
        if opponentPlayed,
            let played = deckAppears.first(where: {
                capturePartner(of: $0, in: fieldToCaptured, consumed: timeline.consumed) != nil
            }) ?? deckAppears.first {
            timeline.spawns[played] = SpatialLayout.opponentHandSpot
            plan(played, into: &timeline, finals: finals, fieldToCaptured: fieldToCaptured)
            deckAppears.removeAll { $0 == played }
        }
        // 3. 山札から現れた札
        for id in deckAppears {
            timeline.spawns[id] = SpatialLayout.deckTop
            plan(id, into: &timeline, finals: finals, fieldToCaptured: fieldToCaptured)
        }
        // 4. 山札の上に提示されていた引き札の解決（場へ置く/獲得）
        for id in finals.keys.sorted()
        where oldZones[id] == .drawn && zones[id] != .drawn {
            plan(id, into: &timeline, finals: finals, fieldToCaptured: fieldToCaptured)
        }
        return timeline
    }

    /// 1 手分の移動を予約する。獲得ペアがあれば相手の場札まで飛んで
    /// がっちゃんこし、2 枚同時に獲得パネルへ移動する。
    private func plan(
        _ mover: Int, into timeline: inout Timeline,
        finals: [Int: Transform], fieldToCaptured: [Int]
    ) {
        guard let final = finals[mover] else { return }
        if let mate = capturePartner(of: mover, in: fieldToCaptured, consumed: timeline.consumed),
            let mateEntity = cards[mate], let mateFinal = finals[mate] {
            timeline.consumed.insert(mate)
            let meet = Transform(translation: mateEntity.position + [0, 0.008, 0])
            timeline.legs[mover] = [
                (timeline.clock, meet),
                (timeline.clock + 0.55, final)
            ]
            timeline.legs[mate] = [(timeline.clock + 0.55, mateFinal)]
            timeline.clock += 1.0
        } else {
            timeline.legs[mover] = [(timeline.clock, final)]
            timeline.clock += 0.5
        }
    }

    private func capturePartner(
        of id: Int, in fieldToCaptured: [Int], consumed: Set<Int>
    ) -> Int? {
        guard zones[id] == .captured, let month = Card.card(id: id)?.month else { return nil }
        return fieldToCaptured.first {
            !consumed.contains($0) && Card.card(id: $0)?.month == month
        }
    }

    // MARK: 適用

    /// `poses` にある札（場・手札・引き札）は盤に残し、獲得済みの札は
    /// 飛来の予約があるときだけ一時的に描いて、着地後に引き上げる。
    private func apply(
        finals: [Int: Transform], poses: [Int: Pose], timeline: Timeline, animated: Bool
    ) {
        for (id, final) in finals {
            let pose = poses[id]
            let legs = timeline.legs[id]
            // 獲得済みで飛来の予約も無い札は獲得パネルが引き受ける
            guard pose != nil || legs != nil, let card = Card.card(id: id) else { continue }
            let entity: ModelEntity
            if let existing = cards[id] {
                entity = existing
            } else {
                entity = makeCardEntity(card)
                if animated {
                    entity.position = timeline.spawns[id] ?? SpatialLayout.deckTop
                }
            }
            if pose != nil {
                retiring.remove(id)
            }
            setGlow(pose?.glowing ?? false, on: entity)
            setBadge(pose?.badgeCount ?? 0, on: entity)
            if pose?.hoverable == true {
                entity.components.set(HoverEffectComponent())
            } else {
                entity.components.remove(HoverEffectComponent.self)
            }
            if let legs {
                run(legs, on: entity, id: id, animated: true)
                targets[id] = final
                if pose == nil {
                    retire(id, after: (legs.last?.0 ?? 0) + 0.45)
                }
            } else if !(targets[id].map { isClose($0, to: final) } ?? false) {
                run([(0, final)], on: entity, id: id, animated: animated)
                targets[id] = final
            }
        }
        let stale = cards.keys.filter {
            finals[$0] == nil && !retiring.contains($0)
        }
        for id in stale {
            remove(id)
        }
    }

    /// 獲得パネルに着地した札を、飛来アニメーションの終わりに合わせて引き上げる。
    private func retire(_ id: Int, after delay: Double) {
        retiring.insert(id)
        let gen = generations[id] ?? 0
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, self.retiring.contains(id), self.generations[id] == gen else { return }
            self.retiring.remove(id)
            self.remove(id)
        }
    }

    private func remove(_ id: Int) {
        cards[id]?.removeFromParent()
        cards.removeValue(forKey: id)
        targets.removeValue(forKey: id)
        generations.removeValue(forKey: id)
    }

    /// 予約された脚を順に実行する。新しい予約が入ったら古い遅延分は破棄される。
    private func run(
        _ legs: [(Double, Transform)], on entity: ModelEntity, id: Int, animated: Bool
    ) {
        let gen = (generations[id] ?? 0) + 1
        generations[id] = gen
        for (delay, transform) in legs {
            if !animated {
                entity.transform = transform
            } else if delay <= 0.01 {
                entity.move(to: transform, relativeTo: root, duration: 0.32, timingFunction: .easeInOut)
            } else {
                Task { @MainActor [weak self, weak entity] in
                    try? await Task.sleep(for: .seconds(delay))
                    guard let self, self.generations[id] == gen, let entity else { return }
                    entity.move(
                        to: transform, relativeTo: self.root,
                        duration: 0.32, timingFunction: .easeInOut)
                }
            }
        }
    }

    private func isClose(_ lhs: Transform, to rhs: Transform) -> Bool {
        simd_distance(lhs.translation, rhs.translation) < 0.0005
            && simd_distance(lhs.rotation.vector, rhs.rotation.vector) < 0.001
            && abs(lhs.scale.x - rhs.scale.x) < 0.001
    }

    private func resetBoard() {
        syncDeck(remaining: 0)
        syncBacks(total: 0, animated: false)
        cards.values.forEach { $0.removeFromParent() }
        cards.removeAll()
        zones.removeAll()
        targets.removeAll()
        generations.removeAll()
        retiring.removeAll()
    }
}

// MARK: - エンティティ生成

extension BoardScene {
    private func makeFeltIfNeeded() {
        guard felt == nil else { return }
        let entity = ModelEntity(
            mesh: .generateBox(
                width: SpatialLayout.feltWidth, height: 0.006,
                depth: SpatialLayout.feltDepth),
            materials: [colors.feltMaterial])
        entity.name = "felt"
        entity.position = [0, -0.003, 0]
        root.addChild(entity)
        felt = entity
    }

    private func makeCardEntity(_ card: Card) -> ModelEntity {
        var material = UnlitMaterial()
        if let texture = try? TextureResource.load(named: card.assetName) {
            material.color = .init(texture: .init(texture))
        } else {
            material.color = .init(tint: .white)
        }
        let entity = ModelEntity(
            mesh: .generatePlane(
                width: SpatialLayout.cardWidth, depth: SpatialLayout.cardHeight,
                cornerRadius: 0.002),
            materials: [material])
        entity.name = "card:\(card.id)"
        entity.generateCollisionShapes(recursive: false)
        entity.components.set(InputTargetComponent())
        entity.components.set(GroundingShadowComponent(castsShadow: true))
        cards[card.id] = entity
        root.addChild(entity)
        return entity
    }

    /// 獲得可能な場札に敷く黄色いハイライトの下敷き。
    private func setGlow(_ on: Bool, on entity: ModelEntity) {
        let existing = entity.children.first { $0.name == "glow" }
        if on, existing == nil {
            let glow = ModelEntity(
                mesh: .generatePlane(
                    width: SpatialLayout.cardWidth * 1.18,
                    depth: SpatialLayout.cardHeight * 1.12,
                    cornerRadius: 0.004),
                materials: [UnlitMaterial(color: colors.glow)])
            glow.name = "glow"
            glow.position = [0, -0.001, 0]
            entity.addChild(glow)
        } else if !on {
            existing?.removeFromParent()
        }
    }

    /// 手札の右上に出すマッチ枚数バッジ（黄色い円盤 + 数字）。
    private func setBadge(_ matches: Int, on entity: ModelEntity) {
        let existing = entity.children.first { $0.name.hasPrefix("badge") }
        let name = "badge:\(matches)"
        if existing?.name == name { return }
        existing?.removeFromParent()
        guard matches > 0 else { return }

        let badge = Entity()
        badge.name = name
        let disc = ModelEntity(
            mesh: .generateCylinder(height: 0.001, radius: 0.0085),
            materials: [UnlitMaterial(color: colors.glow)])
        badge.addChild(disc)

        let mesh = MeshResource.generateText(
            "\(matches)", extrusionDepth: 0.0004,
            font: .systemFont(ofSize: 0.011, weight: .bold))
        let text = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .black)])
        let bounds = text.visualBounds(relativeTo: nil)
        // XY 平面のテキストを札面（XZ）に倒し、円盤の中心に合わせる
        text.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        text.position = [-bounds.center.x, 0.0012, bounds.center.y]
        badge.addChild(text)

        badge.position = [
            SpatialLayout.cardWidth / 2 - 0.010, 0.002,
            -(SpatialLayout.cardHeight / 2) + 0.010
        ]
        entity.addChild(badge)
    }

    /// テーマ変更を、すでに作られているエンティティにも反映する。
    func apply(colors newColors: SpatialColors) {
        guard newColors != colors else { return }
        colors = newColors
        let back = SimpleMaterial(color: colors.cardBack, roughness: 1.0, isMetallic: false)
        felt?.model?.materials = [colors.feltMaterial]
        for entity in backs {
            entity.model?.materials = [back]
        }
        deck?.model?.materials = [back]
    }

    /// 相手の手札（裏向きの薄い赤札）を枚数だけ並べる。
    private func syncBacks(total: Int, animated: Bool) {
        while backs.count > total {
            backs.removeLast().removeFromParent()
        }
        while backs.count < total {
            let back = ModelEntity(
                mesh: .generateBox(
                    width: SpatialLayout.cardWidth, height: 0.0016,
                    depth: SpatialLayout.cardHeight),
                materials: [SimpleMaterial(color: colors.cardBack, roughness: 1.0, isMetallic: false)])
            back.name = "back:\(backs.count)"
            back.components.set(GroundingShadowComponent(castsShadow: true))
            root.addChild(back)
            backs.append(back)
        }
        for (index, back) in backs.enumerated() {
            let transform = Transform(
                translation: [rowX(index, of: total), 0.003, SpatialLayout.opponentHandZ])
            if animated {
                back.move(to: transform, relativeTo: root, duration: 0.32, timingFunction: .easeInOut)
            } else {
                back.transform = transform
            }
        }
    }

    /// 山札は残枚数に応じた高さの束として表現する。
    private func syncDeck(remaining: Int) {
        guard remaining != deckRemaining else { return }
        deckRemaining = remaining
        deck?.removeFromParent()
        deck = nil
        guard remaining > 0 else { return }
        let height = 0.0022 * Float(remaining)
        let entity = ModelEntity(
            mesh: .generateBox(
                width: SpatialLayout.cardWidth + 0.002, height: height,
                depth: SpatialLayout.cardHeight + 0.002),
            materials: [SimpleMaterial(color: colors.cardBack, roughness: 1.0, isMetallic: false)])
        entity.name = "deck"
        entity.position = [SpatialLayout.deckX, height / 2, SpatialLayout.deckZ]
        entity.components.set(GroundingShadowComponent(castsShadow: true))
        root.addChild(entity)
        deck = entity
    }
}
#endif
