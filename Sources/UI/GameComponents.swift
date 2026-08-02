import CoreTransferable
import KoikoiCore
import SwiftUI
import UniformTypeIdentifiers

extension Color {
    /// 盤面の背景色（テーブルグリーン）。
    static let koikoiTable = Color(red: 0.10, green: 0.28, blue: 0.20)
}

extension View {
    /// visionOS では z 方向に浮かせる（他プラットフォームでは何もしない）。
    @ViewBuilder
    func lifted(_ zOffset: CGFloat) -> some View {
        #if os(visionOS)
        offset(z: zOffset)
        #else
        self
        #endif
    }
}

/// 白地から文字を切り抜いたバッジ（背景が文字の形に透ける）。
struct PunchedBadge: View {
    let text: String
    var font: Font = .caption2.bold()
    var horizontalPadding: CGFloat = 6
    var verticalPadding: CGFloat = 2
    var cornerRadius: CGFloat = 5
    var minWidth: CGFloat?

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(.clear)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minWidth: minWidth)
            .background(
                .white.opacity(0.7),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                Text(text)
                    .font(font)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }
}

public extension UTType {
    /// アプリ内 D&D 専用の札ペイロード型（外部の一般 JSON を受けないため）。
    static let koikoiCard = UTType(exportedAs: "io.ngs.Koikoi.card")
}

/// 手札ドラッグのペイロード（アプリ内 D&D 用）。
public struct CardDragPayload: Codable, Transferable, Sendable {
    public let id: Int

    public init(id: Int) {
        self.id = id
    }

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .koikoiCard)
    }
}

/// 札の裏面（赤札 + ドロップシャドウ）。
/// スタック表示では個別の影が重なって黒ずむため `shadowed: false` で消せる。
public struct CardBack: View {
    private let shadowed: Bool

    public init(shadowed: Bool = true) {
        self.shadowed = shadowed
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(red: 0.72, green: 0.18, blue: 0.15))
            .aspectRatio(Card.aspectRatio, contentMode: .fit)
            .shadow(color: .black.opacity(shadowed ? 0.45 : 0), radius: 2, x: 0, y: 1)
    }
}

/// 獲得札の詳細（go-koikoi の writeCapturedDetail 相当）。
/// 種類別のグループ（枚数付き）で並べ、必要ならリーチも示す。
struct CapturedDetail: View {
    let cards: [Card]
    let reaches: [YakuReach]
    let cardWidth: CGFloat

    init(cards: [Card], reaches: [YakuReach] = [], cardWidth: CGFloat) {
        self.cards = cards
        self.reaches = reaches
        self.cardWidth = cardWidth
    }

    private struct Group: Identifiable {
        let label: String
        let type: CardType
        var id: String { label }
    }

    private static let groups: [Group] = [
        Group(label: "光", type: .hikari), Group(label: "タネ", type: .tane),
        Group(label: "短冊", type: .tanzaku), Group(label: "カス", type: .kasu)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !cards.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(Self.groups) { group in
                            let members = cards
                                .filter { $0.type == group.type }
                                .sorted { $0.id < $1.id }
                            if !members.isEmpty {
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 4) {
                                        Text(group.label)
                                            .foregroundStyle(.white.opacity(0.85))
                                        Text("\(members.count)")
                                            .font(.caption2.bold().monospacedDigit())
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(.white.opacity(0.18), in: Capsule())
                                            .foregroundStyle(.white)
                                    }
                                    .font(.caption2)
                                    // matchedGeometryEffect は ScrollView 内で
                                    // サムネイルのジオメトリを壊すため付けない
                                    HStack(spacing: -cardWidth * 0.35) {
                                        ForEach(members) { card in
                                            CardImage(card)
                                                .frame(width: cardWidth)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            if !reaches.isEmpty {
                ReachList(reaches: reaches)
                    .padding(.top, 8)
            }
        }
    }
}

/// リーチ一覧のパネル（タイトル + 役名バッジ + 不足札名）。
struct ReachList: View {
    let reaches: [YakuReach]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("リーチ")
                .font(.caption.bold())
            Rectangle()
                .fill(.white.opacity(0.35))
                .frame(height: 1)
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 5) {
                ForEach(reaches, id: \.self) { reach in
                    GridRow {
                        PunchedBadge(text: reach.kind.rawValue)
                            .fixedSize()  // 「雨四光」等を折り返させない
                            .gridColumnAlignment(.trailing)
                        Text(missingText(for: reach))
                            .font(.caption)
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(10)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.45), lineWidth: 1.5)
        }
        .fixedSize()
    }

    private func missingText(for reach: YakuReach) -> String {
        if let missing = reach.missing, !missing.isEmpty {
            return missing.map(\.name).joined(separator: " / ")
        }
        return "あと1枚"
    }
}

/// 月・局・両者の得点をまとめたスコアボード（リーチパネルと同じ様式）。
struct ScoreboardPanel: View {
    let monthName: String
    let round: Int
    let maxRounds: Int
    let playerScore: Int
    let opponentScore: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                Text(monthName)
                    .font(.system(size: 14.5, weight: .bold))  // caption の約 120%
                Spacer(minLength: 0)
                PunchedBadge(
                    text: "\(round)/\(maxRounds)",
                    font: .caption2.bold().monospacedDigit())
            }
            Rectangle()
                .fill(.white.opacity(0.35))
                .frame(height: 1)
            HStack(spacing: 10) {
                scoreTile(score: playerScore, label: "あなた")
                scoreTile(score: opponentScore, label: "相手")
            }
        }
        .foregroundStyle(.white)
        .padding(10)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.45), lineWidth: 1.5)
        }
        .fixedSize()
    }

    private func scoreTile(score: Int, label: String) -> some View {
        VStack(spacing: 2) {
            PunchedBadge(
                text: "\(score)",
                font: .title3.bold().monospacedDigit(),
                verticalPadding: 4,
                cornerRadius: 8,
                minWidth: 56)
            Text(label)
                .font(.caption2)
        }
    }
}

/// 成立中の役のバッジ列（役名 + 文数チップ。文字での説明は最小限に）。
struct YakuBadges: View {
    let yakus: [Yaku]

    var body: some View {
        if !yakus.isEmpty {
            HStack(spacing: 6) {
                ForEach(yakus, id: \.self) { yaku in
                    HStack(spacing: 5) {
                        Text(yaku.kind.rawValue)
                        Text("\(yaku.points)")
                            .font(.caption2.bold().monospacedDigit())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.white.opacity(0.25), in: Capsule())
                    }
                    .font(.caption2.bold())
                    .padding(.leading, 7)
                    .padding(.trailing, 4)
                    .padding(.vertical, 2)
                    .background(.red.opacity(0.85), in: Capsule())
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

/// 明滅する強調枠（選択候補のハイライト用）。
struct PulsingRing: View {
    @State private var pulsing = false

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .stroke(.yellow, lineWidth: 3)
            .opacity(pulsing ? 1.0 : 0.35)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}

/// 裏返しの札を残り枚数分重ねた山札。
/// 1 枚ごとに縁をずらして重ねるため、残量が高さで視覚的に分かる。
struct DeckStack: View {
    let remaining: Int
    private let cardWidth: CGFloat = 40
    /// 1 枚あたりの積み上がり（縁が見える程度）。
    private let step: CGFloat = 1.1

    var body: some View {
        if remaining > 0 {
            ZStack(alignment: .bottomLeading) {
                ForEach(0..<remaining, id: \.self) { index in
                    CardBack(shadowed: false)
                        .frame(width: cardWidth)
                        .offset(x: CGFloat(index) * 0.3, y: -CGFloat(index) * step)
                        .lifted(CGFloat(index) * 0.6)  // visionOS: 実際に厚みが出る
                }
            }
            // 影は 1 枚ごとではなくスタック全体に薄く 1 つだけ落とす
            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
            .padding(.top, CGFloat(remaining) * step)
            .padding(.trailing, CGFloat(remaining) * 0.3)
            .animation(.default, value: remaining)
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                .aspectRatio(Card.aspectRatio, contentMode: .fit)
                .frame(width: cardWidth)
        }
    }
}

/// 場札 1 枚。
/// - highlighted: 選択候補 / プレビュー手札のマッチ（黄枠・明滅、常に alpha 1）
/// - focused: キーカーソル位置（白枠・太）
/// - dimmed: 場札選択中の候補外（減光）
struct FieldCardView: View {
    let card: Card
    let highlighted: Bool
    let focused: Bool
    let dimmed: Bool
    let tappable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CardImage(card)
                .opacity(dimmed && !highlighted ? 0.4 : 1)
                .lifted(highlighted || focused ? 14 : 2)
                .overlay {
                    if highlighted {
                        PulsingRing()
                    }
                    if focused {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(.white, lineWidth: 3)
                            .padding(-3)
                    }
                }
        }
        .buttonStyle(.plain)
        // disabled はコンテンツを減光してしまうためヒットテストで制御する
        .allowsHitTesting(tappable)
    }
}

/// 手札 1 枚（マッチ枚数バッジ・カーソル/選択枠・ドラッグ対応）。
struct HandCardView: View {
    let card: Card
    let matchCount: Int
    let selected: Bool
    let focused: Bool
    let tappable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CardImage(card)
                .lifted(selected || focused ? 14 : 2)
                .overlay {
                    if selected {
                        PulsingRing()
                    }
                    if focused {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(.white, lineWidth: 3)
                            .padding(-3)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if matchCount > 0 {
                        Text("\(matchCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.black)
                            .padding(4)
                            .background(.yellow, in: Circle())
                            .padding(3)  // 札の内側に収める（隣の札に隠れない）
                    }
                }
        }
        .buttonStyle(.plain)
        // disabled はコンテンツを減光してしまうためヒットテストで制御する
        .allowsHitTesting(tappable)
        .draggable(CardDragPayload(id: card.id)) {
            CardImage(card).frame(width: 56)
        }
    }
}
