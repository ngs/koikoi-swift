#if os(visionOS)
import KoikoiAI
import KoikoiCore
import KoikoiUI
import RealityKit
import SwiftUI

/// AR 空間に水平に置いた花札ボード（俯瞰視点）。
/// 札は xcassets のテクスチャを貼った薄いクアッドとして配置し、
/// 視線 + ピンチのタップで既存のビューモデル intent を呼ぶ。
struct SpatialBoardView: View {
    @State private var session = SpatialSession.shared

    /// 札の実寸（メートル）。実物の花札とほぼ同じ大きさ。
    private static let cardWidth: Float = 0.057
    private static let cardHeight: Float = 0.087

    var body: some View {
        Group {
            if let model = session.model {
                boardView(model: model)
            } else {
                Text("対局がありません。文書ウィンドウから「空間で遊ぶ」を選んでください。")
                    .padding()
            }
        }
    }

    private func boardView(model: GameViewModel) -> some View {
        RealityView { content, attachments in
            let root = Entity()
            root.name = "board"
            content.add(root)
            rebuild(root: root, model: model)

            if let panel = attachments.entity(for: "panel") {
                panel.position = [0, 0.20, -0.28]
                root.addChild(panel)
            }
        } update: { content, attachments in
            guard let root = content.entities.first(where: { $0.name == "board" }) else { return }
            rebuild(root: root, model: model)
            if let panel = attachments.entity(for: "panel") {
                panel.position = [0, 0.20, -0.28]
                if panel.parent == nil { root.addChild(panel) }
            }
        } attachments: {
            Attachment(id: "panel") {
                SpatialControlPanel(model: model)
            }
        }
        .gesture(
            TapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    handleTap(entityName: value.entity.name, model: model)
                }
        )
    }

    // MARK: - 盤面構築

    /// 盤面の全エンティティを作り直す（札数が少ないため毎回再構築で十分）。
    private func rebuild(root: Entity, model: GameViewModel) {
        root.children.filter { $0.name.hasPrefix("card:") || $0.name == "felt" }
            .forEach { $0.removeFromParent() }

        // フェルト盤
        let felt = ModelEntity(
            mesh: .generateBox(width: 0.62, height: 0.005, depth: 0.48, cornerRadius: 0.01),
            materials: [SimpleMaterial(color: UIColor(
                red: 0.10, green: 0.28, blue: 0.20, alpha: 1), isMetallic: false)])
        felt.name = "felt"
        felt.position = [0, -0.0025, 0]
        root.addChild(felt)

        let game = model.game

        // 相手の手札（裏向き）
        layoutRow(
            root: root, count: game.hand(for: .opponent).count,
            z: -0.18, faceUp: false, namePrefix: "back", cards: nil)

        // 場札（2 列まで折り返し）
        let field = game.field
        for (index, card) in field.enumerated() {
            let column = index % 8
            let row = index / 8
            addCard(
                root: root, card: card, name: "card:field:\(card.id)",
                x: rowX(column, of: min(field.count, 8)),
                z: -0.045 + Float(row) * 0.10,
                highlighted: model.highlightedFieldCards.contains(card))
        }

        // 山札
        let deck = ModelEntity(
            mesh: .generateBox(
                width: Self.cardWidth, height: 0.002 * Float(max(game.deck.count, 1)),
                depth: Self.cardHeight, cornerRadius: 0.002),
            materials: [SimpleMaterial(color: UIColor(
                red: 0.72, green: 0.18, blue: 0.15, alpha: 1), isMetallic: false)])
        deck.name = "card:deck"
        deck.position = [-0.26, 0.001 * Float(max(game.deck.count, 1)), -0.045]
        root.addChild(deck)

        // 自分の手札（表向き・手前に少し傾ける）
        let hand = game.hand(for: .player)
        for (index, card) in hand.enumerated() {
            addCard(
                root: root, card: card, name: "card:hand:\(card.id)",
                x: rowX(index, of: hand.count), z: 0.17,
                highlighted: model.pendingHandCard == card,
                tilt: -0.35)
        }
    }

    private func rowX(_ index: Int, of count: Int) -> Float {
        let pitch = Self.cardWidth + 0.008
        return (Float(index) - Float(count - 1) / 2) * pitch
    }

    private func layoutRow(
        root: Entity, count: Int, z: Float, faceUp _: Bool, namePrefix: String, cards _: [Card]?
    ) {
        for index in 0..<count {
            let back = ModelEntity(
                mesh: .generateBox(
                    width: Self.cardWidth, height: 0.002, depth: Self.cardHeight,
                    cornerRadius: 0.002),
                materials: [SimpleMaterial(color: UIColor(
                    red: 0.72, green: 0.18, blue: 0.15, alpha: 1), isMetallic: false)])
            back.name = "card:\(namePrefix):\(index)"
            back.position = [rowX(index, of: count), 0.001, z]
            root.addChild(back)
        }
    }

    private func addCard(
        root: Entity, card: Card, name: String,
        x: Float, z: Float, highlighted: Bool, tilt: Float = 0
    ) {
        var material = UnlitMaterial()
        if let texture = try? TextureResource.load(named: card.assetName) {
            material.color = .init(texture: .init(texture))
        } else {
            material.color = .init(tint: .white)
        }
        let entity = ModelEntity(
            mesh: .generatePlane(width: Self.cardWidth, depth: Self.cardHeight, cornerRadius: 0.002),
            materials: [material])
        entity.name = name
        entity.position = [x, highlighted ? 0.012 : 0.002, z]
        if tilt != 0 {
            entity.orientation = simd_quatf(angle: tilt, axis: [1, 0, 0])
        }
        entity.generateCollisionShapes(recursive: false)
        entity.components.set(InputTargetComponent())
        if highlighted {
            entity.components.set(HoverEffectComponent())
        }
        root.addChild(entity)
    }

    // MARK: - 入力

    private func handleTap(entityName: String, model: GameViewModel) {
        let parts = entityName.split(separator: ":").map(String.init)
        guard parts.count == 3, parts[0] == "card", let id = Int(parts[2]),
            let card = Card.card(id: id) else { return }
        switch parts[1] {
        case "hand": model.tapHandCard(card)
        case "field": model.tapFieldCard(card)
        default: break
        }
    }
}

/// 盤の奥に浮かべる操作パネル（スコア・状態・こいこい/勝負・ラウンド送り）。
private struct SpatialControlPanel: View {
    let model: GameViewModel

    var body: some View {
        VStack(spacing: 10) {
            Text("\(Month(rawValue: (model.game.round - 1) % 12)?.oldName ?? "") \(model.game.round)/\(model.game.maxRounds) ・ あなた \(model.game.score(for: .player)) - 相手 \(model.game.score(for: .opponent))")
                .font(.headline)
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
            }
        }
        .padding(16)
        .glassBackgroundEffect()
    }
}
#endif
