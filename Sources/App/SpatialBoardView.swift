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
            RealityView { content in
                content.add(board.root)
                ground(content, proxy: proxy)
                board.sync(model: model, animated: false)
            } update: { content in
                ground(content, proxy: proxy)
                board.sync(model: model, animated: true)
            }
            .gesture(
                TapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        handleTap(entityName: value.entity.name)
                    })
        }
        // 操作 UI は attachment ではなく ornament で出す
        // （動的 attachment は表示が不安定になったため。ornament は SwiftUI 管理で確実）
        .ornament(attachmentAnchor: .scene(.back)) {
            if let model {
                SpatialControlPanel(
                    model: model,
                    onSave: { exporting = true },
                    onQuit: quitToTitle)
            } else {
                setupPanel
            }
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
        // 2D 用の獲得アニメ演出（適用前ディレイ）は使わず、3D 側のタイムラインで表現する
        let model = GameViewModel(record: record, captureAnimationsEnabled: false)
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
/// ゾーン遷移（手札→場→獲得、山札からの出現）を分類し、1 手ずつ時間差の
/// タイムラインに載せて move(to:) でアニメーションする。
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

    private enum Zone { case hand, field, captured, drawn }

    // 実寸（メートル）。札は実物の花札とほぼ同じ大きさ。
    private static let cardWidth: Float = 0.057
    private static let cardHeight: Float = 0.087
    private static let handPitch: Float = 0.065
    private static let feltWidth: Float = 0.72
    private static let feltDepth: Float = 0.60
    private static let deckX: Float = -0.30
    private static let deckZ: Float = 0.01
    private static let deckTop: SIMD3<Float> = [deckX, 0.06, deckZ]
    private static let opponentHandSpot: SIMD3<Float> = [0, 0.02, -0.17]
    private static let feltColor = UIColor(Color(red: 0.10, green: 0.28, blue: 0.20))
    private static let cardBackColor = UIColor(Color(red: 0.72, green: 0.18, blue: 0.15))
    private static let glowColor = UIColor(Color(red: 1.00, green: 0.82, blue: 0.25))

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

        let opponentTotal = game.hand(for: .opponent).count
        let opponentPlayed = opponentTotal < backs.count
        syncBacks(total: opponentTotal, animated: animated)
        syncDeck(remaining: game.deck.count)

        let oldZones = zones
        zones = newZones

        // 新規登場した札（山札から引かれた・相手の手元から出た・配り直し）
        let appears = poses.keys.filter { oldZones[$0] == nil && cards[$0] == nil }
        var timeline = Timeline()
        if animated && appears.count <= 4 {
            timeline = buildTimeline(
                poses: poses, oldZones: oldZones,
                appears: appears.sorted(), opponentPlayed: opponentPlayed)
        }
        applyPoses(poses, timeline: timeline, animated: animated)
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
            let rowTotal = row == 0 ? min(field.count, 8) : field.count - 8
            let isCandidate = candidates.contains(card.id)
            poses[card.id] = Pose(
                position: [rowX(index % 8, of: rowTotal), 0.003, -0.04 + Float(row) * 0.10],
                raised: isCandidate,
                glowing: isCandidate || capturable.contains(card.id),
                hoverable: isCandidate)
            newZones[card.id] = .field
        }

        // 自分の手札（手前・プレイヤー側へ面を起こして持ち札らしく）
        let hand = game.hand(for: .player)
        let selecting = model.prompt == .selectHand
        for (index, card) in hand.enumerated() {
            poses[card.id] = Pose(
                position: [rowX(index, of: hand.count), 0.018, 0.17],
                tilt: 0.35,
                raised: model.pendingHandCard == card,
                hoverable: selecting,
                badgeCount: selecting ? game.matchingFieldCards(for: card).count : 0)
            newZones[card.id] = .hand
        }

        // 山札から引いた札は山札の上に浮かべて提示
        if let drawn = model.drawnCard {
            poses[drawn.id] = Pose(position: [Self.deckX, 0.07, Self.deckZ], tilt: 0.55)
            newZones[drawn.id] = .drawn
        }

        // 獲得札は盤の手前/奥の縁に小さく並べる
        layoutCaptured(game.captured(for: .player), z: 0.27, into: &poses, zones: &newZones)
        layoutCaptured(game.captured(for: .opponent), z: -0.27, into: &poses, zones: &newZones)
    }

    private func rowX(_ index: Int, of total: Int) -> Float {
        (Float(index) - Float(total - 1) / 2) * Self.handPitch
    }

    private func layoutCaptured(
        _ captured: [Card], z: Float,
        into poses: inout [Int: Pose], zones newZones: inout [Int: Zone]
    ) {
        let pitch: Float = min(0.024, 0.6 / Float(max(captured.count, 1)))
        for (index, card) in captured.enumerated() {
            poses[card.id] = Pose(
                position: [-0.30 + Float(index) * pitch, 0.003, z],
                scale: 0.6)
            newZones[card.id] = .captured
        }
    }

    private func transform(for pose: Pose) -> Transform {
        Transform(
            scale: .init(repeating: pose.scale),
            rotation: simd_quatf(angle: pose.tilt, axis: [1, 0, 0]),
            translation: pose.position + [0, pose.raised ? 0.016 : 0, 0])
    }

    // MARK: 手番シーケンスの組み立て

    private func buildTimeline(
        poses: [Int: Pose], oldZones: [Int: Zone], appears: [Int], opponentPlayed: Bool
    ) -> Timeline {
        var timeline = Timeline()
        let fieldToCaptured = poses.keys.filter {
            oldZones[$0] == .field && zones[$0] == .captured
        }

        // 1. 自分の手札から出した札
        for id in poses.keys.sorted()
        where oldZones[id] == .hand && zones[id] != .hand {
            plan(id, into: &timeline, poses: poses, fieldToCaptured: fieldToCaptured)
        }
        // 2. 相手の手元から出た札（裏札が減ったときの出現札。獲得ペアのある札を優先）
        var deckAppears = appears
        if opponentPlayed,
            let played = deckAppears.first(where: {
                capturePartner(of: $0, in: fieldToCaptured, consumed: timeline.consumed) != nil
            }) ?? deckAppears.first {
            timeline.spawns[played] = Self.opponentHandSpot
            plan(played, into: &timeline, poses: poses, fieldToCaptured: fieldToCaptured)
            deckAppears.removeAll { $0 == played }
        }
        // 3. 山札から現れた札
        for id in deckAppears {
            timeline.spawns[id] = Self.deckTop
            plan(id, into: &timeline, poses: poses, fieldToCaptured: fieldToCaptured)
        }
        // 4. 山札の上に提示されていた引き札の解決（場へ置く/獲得）
        for id in poses.keys.sorted()
        where oldZones[id] == .drawn && zones[id] != .drawn {
            plan(id, into: &timeline, poses: poses, fieldToCaptured: fieldToCaptured)
        }
        return timeline
    }

    /// 1 手分の移動を予約する。獲得ペアがあれば相手の場札まで飛んで
    /// がっちゃんこし、2 枚同時に獲得置き場へ移動する。
    private func plan(
        _ mover: Int, into timeline: inout Timeline,
        poses: [Int: Pose], fieldToCaptured: [Int]
    ) {
        guard let pose = poses[mover] else { return }
        if let mate = capturePartner(of: mover, in: fieldToCaptured, consumed: timeline.consumed),
            let mateEntity = cards[mate], let matePose = poses[mate] {
            timeline.consumed.insert(mate)
            let meet = Transform(translation: mateEntity.position + [0, 0.008, 0])
            timeline.legs[mover] = [
                (timeline.clock, meet),
                (timeline.clock + 0.55, transform(for: pose))
            ]
            timeline.legs[mate] = [(timeline.clock + 0.55, transform(for: matePose))]
            timeline.clock += 1.0
        } else {
            timeline.legs[mover] = [(timeline.clock, transform(for: pose))]
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

    private func applyPoses(
        _ poses: [Int: Pose], timeline: Timeline, animated: Bool
    ) {
        for (id, pose) in poses {
            guard let card = Card.card(id: id) else { continue }
            let entity: ModelEntity
            if let existing = cards[id] {
                entity = existing
            } else {
                entity = makeCardEntity(card)
                if animated {
                    entity.position = timeline.spawns[id] ?? Self.deckTop
                }
            }
            setGlow(pose.glowing, on: entity)
            setBadge(pose.badgeCount, on: entity)
            if pose.hoverable {
                entity.components.set(HoverEffectComponent())
            } else {
                entity.components.remove(HoverEffectComponent.self)
            }
            let final = transform(for: pose)
            if let legs = timeline.legs[id] {
                run(legs, on: entity, id: id, animated: true)
                targets[id] = final
            } else if !(targets[id].map { isClose($0, to: final) } ?? false) {
                run([(0, final)], on: entity, id: id, animated: animated)
                targets[id] = final
            }
        }
        let stale = cards.keys.filter { poses[$0] == nil }
        for id in stale {
            cards[id]?.removeFromParent()
            cards.removeValue(forKey: id)
            targets.removeValue(forKey: id)
            generations.removeValue(forKey: id)
        }
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
    }
}

// MARK: - エンティティ生成

extension BoardScene {
    private func makeFeltIfNeeded() {
        guard felt == nil else { return }
        let entity = ModelEntity(
            mesh: .generateBox(width: Self.feltWidth, height: 0.006, depth: Self.feltDepth),
            materials: [SimpleMaterial(color: Self.feltColor, roughness: 1.0, isMetallic: false)])
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
                    width: Self.cardWidth * 1.18, depth: Self.cardHeight * 1.12,
                    cornerRadius: 0.004),
                materials: [UnlitMaterial(color: Self.glowColor)])
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
            materials: [UnlitMaterial(color: Self.glowColor)])
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

        badge.position = [Self.cardWidth / 2 - 0.010, 0.002, -(Self.cardHeight / 2) + 0.010]
        entity.addChild(badge)
    }

    /// 相手の手札（裏向きの薄い赤札）を枚数だけ並べる。
    private func syncBacks(total: Int, animated: Bool) {
        while backs.count > total {
            backs.removeLast().removeFromParent()
        }
        while backs.count < total {
            let back = ModelEntity(
                mesh: .generateBox(
                    width: Self.cardWidth, height: 0.0016, depth: Self.cardHeight),
                materials: [SimpleMaterial(color: Self.cardBackColor, roughness: 1.0, isMetallic: false)])
            back.name = "back:\(backs.count)"
            back.components.set(GroundingShadowComponent(castsShadow: true))
            root.addChild(back)
            backs.append(back)
        }
        for (index, back) in backs.enumerated() {
            let transform = Transform(translation: [rowX(index, of: total), 0.003, -0.17])
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
                width: Self.cardWidth + 0.002, height: height, depth: Self.cardHeight + 0.002),
            materials: [SimpleMaterial(color: Self.cardBackColor, roughness: 1.0, isMetallic: false)])
        entity.name = "deck"
        entity.position = [Self.deckX, height / 2, Self.deckZ]
        entity.components.set(GroundingShadowComponent(castsShadow: true))
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
