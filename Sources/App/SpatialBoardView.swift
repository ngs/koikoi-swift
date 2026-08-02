#if os(visionOS)
import KoikoiAI
import KoikoiCore
import KoikoiUI
import RealityKit
import SwiftUI
import UniformTypeIdentifiers

/// visionOS のメイン画面。AR 空間に実寸大のフェルト盤を水平に置き、俯瞰で花札を遊ぶ。
/// 対局設定・保存/読込・こいこい判断はすべて盤上のガラスパネルで行う。
/// 札 1 枚 = 1 エンティティを使い回し、ゾーン間の移動は move(to:) の 3D アニメーションで表現する。
struct SpatialBoardView: View {
    @State private var model: GameViewModel?
    @State private var moves: [Move] = []
    @State private var exporting = false
    @State private var importing = false
    @State private var board = BoardScene()

    var body: some View {
        GeometryReader3D { proxy in
            RealityView { content, attachments in
                content.add(board.root)
                ground(content, proxy: proxy)
                board.sync(model: model, animated: false)
                place(attachments)
            } update: { content, attachments in
                ground(content, proxy: proxy)
                board.sync(model: model, animated: true)
                place(attachments)
            } attachments: {
                Attachment(id: "setup") {
                    if model == nil { setupPanel }
                }
                Attachment(id: "panel") {
                    if let model {
                        SpatialControlPanel(
                            model: model,
                            onSave: { exporting = true },
                            onQuit: quitToTitle)
                    }
                }
            }
            .gesture(
                TapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        handleTap(entityName: value.entity.name)
                    })
        }
        .onAppear { GameCenterService.shared.authenticate() }
        .fileExporter(
            isPresented: $exporting,
            document: model.map { KoikoiGameDocument(record: $0.makeRecord(moves: moves)) },
            contentType: .koikoiGame,
            defaultFilename: "Koikoi"
        ) { _ in }
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

    // MARK: - 対局セッション

    private var setupPanel: some View {
        VStack(spacing: 20) {
            GameSetupView { rounds, difficulty in
                start(record: GameRecord(
                    rounds: rounds, difficulty: difficulty,
                    seed: UInt64.random(in: .min ... .max)))
            }
            Button("保存した対局を開く", systemImage: "folder") {
                importing = true
            }
        }
        .padding(24)
        .glassBackgroundEffect()
    }

    private func start(record: GameRecord) {
        moves = record.moves
        let model = GameViewModel(record: record)
        model.onMoveApplied = { moves.append($0) }
        self.model = model
    }

    private func quitToTitle() {
        model = nil
        moves = []
    }

    // MARK: - RealityView 補助

    /// ボードの原点を volume の底面に接地させる。
    private func ground(_ content: RealityViewContent, proxy: GeometryProxy3D) {
        let bounds = content.convert(proxy.frame(in: .local), from: .local, to: .scene)
        board.root.position.y = bounds.min.y
    }

    private func place(_ attachments: RealityViewAttachments) {
        if let setup = attachments.entity(for: "setup") {
            setup.position = [0, 0.30, 0.05]
            if setup.parent == nil { board.root.addChild(setup) }
        }
        if let panel = attachments.entity(for: "panel") {
            panel.position = [0, 0.26, -0.34]
            if panel.parent == nil { board.root.addChild(panel) }
        }
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

/// 盤面のエンティティを札 ID ごとに保持し、ビューモデルの状態へ差分同期するストア。
/// 位置が変わった札は move(to:) でアニメーションしながらゾーン間を移動する。
@MainActor
private final class BoardScene {
    let root = Entity()

    private var cards: [Int: ModelEntity] = [:]
    private var backs: [ModelEntity] = []
    private var felt: ModelEntity?
    private var deck: ModelEntity?
    private var deckRemaining = -1

    // 実寸（メートル）。札は実物の花札とほぼ同じ大きさ。
    private static let cardWidth: Float = 0.057
    private static let cardHeight: Float = 0.087
    private static let handPitch: Float = 0.065
    private static let feltWidth: Float = 0.72
    private static let feltDepth: Float = 0.60
    private static let deckX: Float = -0.30
    private static let deckZ: Float = 0.01
    private static let feltColor = UIColor(Color(red: 0.10, green: 0.28, blue: 0.20))
    private static let cardBackColor = UIColor(Color(red: 0.72, green: 0.18, blue: 0.15))

    /// 札 1 枚の目標配置。
    private struct Pose {
        var position: SIMD3<Float>
        var tilt: Float = 0
        var scale: Float = 1
        var raised = false
        var hoverable = false
    }

    func sync(model: GameViewModel?, animated: Bool) {
        makeFeltIfNeeded()

        guard let model else {
            syncDeck(remaining: 0)
            syncBacks(total: 0, animated: false)
            cards.values.forEach { $0.removeFromParent() }
            cards.removeAll()
            return
        }

        let game = model.game
        var poses: [Int: Pose] = [:]

        // 場札（8 枚で折り返して 2 列）
        let field = game.field
        for (index, card) in field.enumerated() {
            let row = index / 8
            let rowTotal = row == 0 ? min(field.count, 8) : field.count - 8
            let highlighted = model.highlightedFieldCards.contains(card)
            poses[card.id] = Pose(
                position: [
                    rowX(index % 8, of: rowTotal),
                    0.003,
                    -0.04 + Float(row) * 0.10
                ],
                raised: highlighted,
                hoverable: highlighted)
        }

        // 自分の手札（手前・少し起こして持ち札らしく）
        let hand = game.hand(for: .player)
        let selecting = model.prompt == .selectHand
        for (index, card) in hand.enumerated() {
            poses[card.id] = Pose(
                position: [rowX(index, of: hand.count), 0.003, 0.17],
                tilt: -0.35,
                raised: model.pendingHandCard == card,
                hoverable: selecting)
        }

        // 山札から引いた札は山札の上に浮かべて提示
        if let drawn = model.drawnCard {
            poses[drawn.id] = Pose(
                position: [Self.deckX, 0.07, Self.deckZ],
                tilt: -0.55)
        }

        // 獲得札は盤の手前/奥の縁に小さく並べる
        layoutCaptured(game.captured(for: .player), z: 0.27, into: &poses)
        layoutCaptured(game.captured(for: .opponent), z: -0.27, into: &poses)

        syncBacks(total: game.hand(for: .opponent).count, animated: animated)
        syncDeck(remaining: game.deck.count)

        // 差分適用: 新しい札は山札の上から出現し、既存の札は目標へ飛ぶ
        for (id, pose) in poses {
            guard let card = Card.card(id: id) else { continue }
            let entity: ModelEntity
            if let existing = cards[id] {
                entity = existing
            } else {
                entity = makeCardEntity(card)
                if animated {
                    entity.position = [Self.deckX, 0.07, Self.deckZ]
                }
            }
            apply(pose, to: entity, animated: animated)
        }
        for (id, entity) in cards where poses[id] == nil {
            entity.removeFromParent()
            cards.removeValue(forKey: id)
        }
    }

    // MARK: 配置計算

    private func rowX(_ index: Int, of total: Int) -> Float {
        (Float(index) - Float(total - 1) / 2) * Self.handPitch
    }

    private func layoutCaptured(_ captured: [Card], z: Float, into poses: inout [Int: Pose]) {
        let pitch: Float = min(0.024, 0.6 / Float(max(captured.count, 1)))
        for (index, card) in captured.enumerated() {
            poses[card.id] = Pose(
                position: [-0.30 + Float(index) * pitch, 0.003, z],
                scale: 0.6)
        }
    }

    private func apply(_ pose: Pose, to entity: ModelEntity, animated: Bool) {
        let transform = Transform(
            scale: .init(repeating: pose.scale),
            rotation: simd_quatf(angle: pose.tilt, axis: [1, 0, 0]),
            translation: pose.position + [0, pose.raised ? 0.016 : 0, 0])
        if pose.hoverable {
            entity.components.set(HoverEffectComponent())
        } else {
            entity.components.remove(HoverEffectComponent.self)
        }
        if animated {
            entity.move(to: transform, relativeTo: root, duration: 0.35, timingFunction: .easeInOut)
        } else {
            entity.transform = transform
        }
    }

    // MARK: エンティティ生成

    private func makeFeltIfNeeded() {
        guard felt == nil else { return }
        let entity = ModelEntity(
            mesh: .generateBox(
                width: Self.feltWidth, height: 0.006, depth: Self.feltDepth, cornerRadius: 0.012),
            materials: [SimpleMaterial(color: Self.feltColor, isMetallic: false)])
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
                width: Self.cardWidth, depth: Self.cardHeight, cornerRadius: 0.002),
            materials: [material])
        entity.name = "card:\(card.id)"
        entity.generateCollisionShapes(recursive: false)
        entity.components.set(InputTargetComponent())
        cards[card.id] = entity
        root.addChild(entity)
        return entity
    }

    /// 相手の手札（裏向きの薄い赤札）を枚数だけ並べる。
    private func syncBacks(total: Int, animated: Bool) {
        while backs.count > total {
            backs.removeLast().removeFromParent()
        }
        while backs.count < total {
            let back = ModelEntity(
                mesh: .generateBox(
                    width: Self.cardWidth, height: 0.0016, depth: Self.cardHeight,
                    cornerRadius: 0.002),
                materials: [SimpleMaterial(color: Self.cardBackColor, isMetallic: false)])
            back.name = "back:\(backs.count)"
            root.addChild(back)
            backs.append(back)
        }
        for (index, back) in backs.enumerated() {
            let transform = Transform(translation: [rowX(index, of: total), 0.003, -0.17])
            if animated {
                back.move(to: transform, relativeTo: root, duration: 0.35, timingFunction: .easeInOut)
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
                width: Self.cardWidth + 0.002, height: height, depth: Self.cardHeight + 0.002,
                cornerRadius: 0.002),
            materials: [SimpleMaterial(color: Self.cardBackColor, isMetallic: false)])
        entity.name = "deck"
        entity.position = [Self.deckX, height / 2, Self.deckZ]
        root.addChild(entity)
        deck = entity
    }
}

// MARK: - 操作パネル

/// 盤の奥に浮かべる操作パネル（スコア・状態・こいこい/勝負・ラウンド送り・保存）。
private struct SpatialControlPanel: View {
    let model: GameViewModel
    let onSave: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(scoreLine)
                .font(.headline)
            promptView
            HStack(spacing: 20) {
                Button("保存", systemImage: "square.and.arrow.down", action: onSave)
                Button("タイトルへ", systemImage: "house", action: onQuit)
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(20)
        .frame(minWidth: 300)
        .glassBackgroundEffect()
    }

    private var scoreLine: String {
        let month = Month(rawValue: (model.game.round - 1) % 12)?.oldName ?? ""
        return "\(month) \(model.game.round)/\(model.game.maxRounds) ・ "
            + "あなた \(model.game.score(for: .player)) - 相手 \(model.game.score(for: .opponent))"
    }

    @ViewBuilder private var promptView: some View {
        switch model.prompt {
        case .selectHand:
            Text("手札を選んでください")
        case .selectField:
            Text("取る場札を選んでください")
        case .opponentTurn:
            Text("相手の番…")
        case .decideKoikoi(let newYaku):
            Text(newYaku.map { "\($0.kind.rawValue) \($0.points)文" }.joined(separator: "・"))
            HStack {
                Button("こいこい！") { model.decide(koikoi: true) }
                    .buttonStyle(.borderedProminent)
                Button("勝負") { model.decide(koikoi: false) }
            }
        case .roundEnd(let outcome):
            Text(outcome.winner == .player ? "あなたの勝ち！ \(outcome.points)文" :
                outcome.winner == .opponent ? "相手の勝ち \(outcome.points)文" : "流局")
            Button("次へ") { model.proceedAfterRound() }
                .buttonStyle(.borderedProminent)
        case .matchEnd(let winner):
            Text(winner == .player ? "対局勝利！" : winner == .opponent ? "対局敗北…" : "引き分け")
            Button("タイトルへ戻る", action: onQuit)
                .buttonStyle(.borderedProminent)
        }
    }
}
#endif
