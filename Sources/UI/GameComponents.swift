import CoreTransferable
import KoikoiCore
import SwiftUI
import UniformTypeIdentifiers

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

/// `fixedSize()` を条件付きで適用する（分岐で View の同一性を変えないため modifier にする）。
struct ConditionalFixedSize: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        content.fixedSize(horizontal: enabled, vertical: enabled)
    }
}

/// 白地から文字を切り抜いたバッジ（背景が文字の形に透ける）。
struct PunchedBadge: View {
    @Environment(\.koikoiPalette)
    private var palette
    let text: String
    /// 狭い列では語の切れ目で折り返す（既定は 1 行）。
    var wraps = false
    var font: Font = .caption2.bold()
    var horizontalPadding: CGFloat = 6
    var verticalPadding: CGFloat = 2
    var cornerRadius: CGFloat = 5
    var minWidth: CGFloat?

    var body: some View {
        label
            .foregroundStyle(.clear)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minWidth: minWidth)
            .background(
                palette.ink.opacity(0.7),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                label
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }

    /// 切り抜き前後で同じ組版になるよう、文字は 1 箇所で組む。
    private var label: some View {
        Text(text)
            .font(font)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: wraps)
    }
}

public extension UTType {
    /// アプリ内 D&D 専用の札ペイロード型（外部の一般 JSON を受けないため）。
    static let koikoiCard = UTType(exportedAs: "io.ngs.Koikoi.card")
}

/// 手札ドラッグのペイロード（アプリ内 D&D 用）。
struct CardDragPayload: Codable, Transferable, Sendable {
    let id: Int

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .koikoiCard)
    }
}

/// 札の裏面（赤札 + ドロップシャドウ）。
/// スタック表示では個別の影が重なって黒ずむため `shadowed: false` で消せる。
struct CardBack: View {
    @Environment(\.koikoiPalette)
    private var palette
    private let shadowed: Bool

    init(shadowed: Bool = true) {
        self.shadowed = shadowed
    }

    var body: some View {
        CardShape()
            .fill(palette.cardBack)
            // 暗い縁取りで、重ねたときも 1 枚ずつの境界が見えるようにする
            .overlay {
                CardShape()
                    .stroke(palette.cardBackEdge, lineWidth: 1)
                    .padding(0.5)
            }
            .aspectRatio(Card.aspectRatio, contentMode: .fit)
            .shadow(color: .black.opacity(shadowed ? 0.45 : 0), radius: 2, x: 0, y: 1)
    }
}

/// 獲得札の詳細（go-koikoi の writeCapturedDetail 相当）。
/// 種類別のグループ（枚数付き）で並べ、必要ならリーチも示す。
struct CapturedDetail: View {
    @Environment(\.koikoiPalette)
    private var palette
    let cards: [Card]
    let reaches: [YakuReach]
    let cardWidth: CGFloat
    /// 並べる向き。横向き iPhone の左右カラムでは縦に積む（横スクロールは使えない）。
    let axis: Axis
    /// 縦積みのときの 1 行あたりの枚数（列の幅から決め打ちする）。
    let columns: Int

    init(
        cards: [Card], reaches: [YakuReach] = [], cardWidth: CGFloat,
        axis: Axis = .horizontal, columns: Int = 3
    ) {
        self.cards = cards
        self.reaches = reaches
        self.cardWidth = cardWidth
        self.axis = axis
        self.columns = columns
    }

    private struct Group: Identifiable {
        let type: CardType
        var label: String { type.localizedName }
        var id: Int { type.rawValue }
    }

    private static let groups: [Group] = [
        Group(type: .hikari), Group(type: .tane),
        Group(type: .tanzaku), Group(type: .kasu)
    ]

    var body: some View {
        if axis == .vertical {
            verticalBody
        } else {
            horizontalBody
        }
    }

    private var horizontalBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !cards.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(Self.groups) { group in
                            let members = members(of: group)
                            if !members.isEmpty {
                                VStack(alignment: .leading, spacing: 1) {
                                    label(for: group, count: members.count)
                                    // matchedGeometryEffect は ScrollView 内で
                                    // サムネイルのジオメトリを壊すため付けない
                                    // 高さは比率から確定させる（縦が詰まったとき
                                    // 横スクロールごと 0 に潰れて札が消えるのを防ぐ）
                                    HStack(spacing: -cardWidth * 0.35) {
                                        ForEach(members) { card in
                                            CardImage(card)
                                                .frame(
                                                    width: cardWidth,
                                                    height: cardWidth / Card.aspectRatio)
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

    /// 縦積み。細い列に収めるため札は重ねずグリッドで折り返す（リーチは呼び出し側が別に描く）。
    private var verticalBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Self.groups) { group in
                let members = members(of: group)
                if !members.isEmpty {
                    VStack(alignment: .leading, spacing: 1) {
                        label(for: group, count: members.count)
                        LazyVGrid(
                            // 列数は幅から決め打ちする（提案幅に依存させると
                            // 兄弟ビューが広がったときに 1 行の枚数まで増えてしまう）
                            columns: Array(
                                repeating: GridItem(
                                    .fixed(cardWidth), spacing: 2, alignment: .leading),
                                count: columns),
                            alignment: .leading,
                            spacing: 2
                        ) {
                            ForEach(members) { card in
                                CardImage(card)
                                    .frame(width: cardWidth, height: cardWidth / Card.aspectRatio)
                            }
                        }
                        // 列の幅より広がらない（獲得札が増えても中央にはみ出さない）
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 追加時にグリッドが滑るとゴーストのサムネイルが残るため、その場で差し込む
        .animation(nil, value: cards)
    }

    private func members(of group: Group) -> [Card] {
        cards.filter { $0.type == group.type }.sorted { $0.id < $1.id }
    }

    private func label(for group: Group, count: Int) -> some View {
        HStack(spacing: 4) {
            Text(verbatim: group.label)
                .foregroundStyle(palette.ink.opacity(0.85))
            Text(verbatim: String(count))
                .font(.caption2.bold().monospacedDigit())
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(palette.ink.opacity(0.18), in: Capsule())
                .foregroundStyle(palette.ink)
        }
        .font(.caption2)
    }
}

/// リーチ一覧のパネル（タイトル + 役名バッジ + 不足札名）。
struct ReachList: View {
    @Environment(\.koikoiPalette)
    private var palette
    let reaches: [YakuReach]
    /// 狭い列に置くとき、不足札名を折り返して幅に収める。
    var wraps: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("One Away", bundle: .module)
                .font(.caption.bold())
            Rectangle()
                .fill(palette.ink.opacity(0.35))
                .frame(height: 1)
            if wraps {
                // 狭い列では 2 列グリッドだと不足札名が 1 文字ずつ折り返すため縦に積む
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(reaches, id: \.self) { reach in
                        VStack(alignment: .leading, spacing: 2) {
                            PunchedBadge(text: reach.kind.localizedName, wraps: true)
                            Text(verbatim: missingText(for: reach))
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 5) {
                    ForEach(reaches, id: \.self) { reach in
                        GridRow {
                            PunchedBadge(text: reach.kind.localizedName)
                                .fixedSize()  // 「雨四光」等を折り返させない
                                .gridColumnAlignment(.trailing)
                            Text(verbatim: missingText(for: reach))
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .foregroundStyle(palette.ink)
        .padding(10)
        .frame(maxWidth: wraps ? .infinity : nil, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(palette.ink.opacity(0.45), lineWidth: 1.5)
        }
        .modifier(ConditionalFixedSize(enabled: !wraps))
    }

    private func missingText(for reach: YakuReach) -> String {
        if let missing = reach.missing, !missing.isEmpty {
            return missing.map(\.localizedName).joined(separator: " / ")
        }
        return String(localized: "1 more card", bundle: .module)
    }
}

/// 月・局・両者の得点をまとめたスコアボード（リーチパネルと同じ様式）。
struct ScoreboardPanel: View {
    /// 置き場所に応じた形。`panel` は縦積み、`strip` は 1 行の横長（横向き iPhone の上端）。
    enum Style {
        case panel
        case strip
    }

    @Environment(\.koikoiPalette)
    private var palette
    let monthName: String
    let round: Int
    let maxRounds: Int
    let playerScore: Int
    let opponentScore: Int
    var style: Style = .panel

    var body: some View {
        content
            .foregroundStyle(palette.ink)
            .padding(.horizontal, style == .strip ? 8 : 10)
            .padding(.vertical, style == .strip ? 6 : 10)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(palette.ink.opacity(0.45), lineWidth: 1.5)
            }
            .fixedSize()
    }

    @ViewBuilder private var content: some View {
        switch style {
        case .panel:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 16) {
                    Text(verbatim: monthName)
                        .font(.system(size: 14.5, weight: .bold))  // caption の約 120%
                    Spacer(minLength: 0)
                    roundBadge
                }
                Rectangle()
                    .fill(palette.ink.opacity(0.35))
                    .frame(height: 1)
                HStack(spacing: 10) {
                    scoreTile(score: playerScore, label: String(localized: "You", bundle: .module))
                    scoreTile(
                        score: opponentScore,
                        label: String(localized: "Opponent", bundle: .module))
                }
            }
        case .strip:
            HStack(spacing: 10) {
                Text(verbatim: monthName)
                    .font(.headline)
                roundBadge
                Rectangle()
                    .fill(palette.ink.opacity(0.35))
                    .frame(width: 1, height: 18)
                inlineScore(score: playerScore, label: String(localized: "You", bundle: .module))
                inlineScore(
                    score: opponentScore,
                    label: String(localized: "Opponent", bundle: .module))
            }
        }
    }

    private var roundBadge: some View {
        PunchedBadge(
            text: "\(round)/\(maxRounds)",
            font: .caption2.bold().monospacedDigit())
    }

    private func scoreTile(score: Int, label: String) -> some View {
        VStack(spacing: 2) {
            PunchedBadge(
                text: "\(score)",
                font: .title3.bold().monospacedDigit(),
                verticalPadding: 4,
                cornerRadius: 8,
                minWidth: 56)
            Text(verbatim: label)
                .font(.caption2)
        }
    }

    /// 1 行版の得点（ラベルはバッジの下ではなく横に置く）。
    private func inlineScore(score: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text(verbatim: label)
                .font(.caption2)
            PunchedBadge(
                text: "\(score)",
                font: .subheadline.bold().monospacedDigit(),
                verticalPadding: 3,
                cornerRadius: 6,
                minWidth: 36)
        }
    }
}

/// 横向きの側方カラムのスクロール。負のパディングでスクロール領域を
/// 画面の物理的な上端・下端まで広げ、同じ量を内容の余白として戻す。
/// 静止時の先頭/末尾はセーフエリアの内側に来つつ、送った中身は
/// ツールバーのガラスの下と画面端まで描かれる。
struct SideColumnScroll: ViewModifier {
    /// 盤面の上端から画面上端まで（セーフエリア + 盤面の外周パディング）。
    let topMargin: CGFloat
    /// 盤面の下端から画面下端まで。
    let bottomMargin: CGFloat

    func body(content: Content) -> some View {
        content
            .contentMargins(.top, topMargin, for: .scrollContent)
            .contentMargins(.bottom, bottomMargin, for: .scrollContent)
            .padding(.top, -topMargin)
            .padding(.bottom, -bottomMargin)
    }
}

/// 対局の状態からスコアボードを組み立てる（盤面とツールバーで月・局の算出を共有する）。
struct GameScoreboard: View {
    let model: GameViewModel
    var style: ScoreboardPanel.Style = .panel

    var body: some View {
        ScoreboardPanel(
            monthName: Month(rawValue: (model.game.round - 1) % 12)?.localizedMonthName ?? "",
            round: model.game.round,
            maxRounds: model.game.maxRounds,
            playerScore: model.game.score(for: .player),
            opponentScore: model.game.score(for: .opponent),
            style: style)
    }
}

/// 成立中の役のバッジ列（役名 + 文数チップ。文字での説明は最小限に）。
struct YakuBadges: View {
    @Environment(\.koikoiPalette)
    private var palette
    let yakus: [Yaku]
    /// 狭い列では 1 行 1 バッジに積み、役名を語の切れ目で折り返す。
    var stacked = false

    var body: some View {
        if !yakus.isEmpty {
            if stacked {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(yakus, id: \.self) { yaku in
                        badge(yaku)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    ForEach(yakus, id: \.self) { yaku in
                        badge(yaku)
                    }
                }
            }
        }
    }

    private func badge(_ yaku: Yaku) -> some View {
        // 文数チップは折り返した役名の 1 行目に揃える
        HStack(alignment: .top, spacing: 5) {
            Text(verbatim: yaku.kind.localizedName)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: stacked)
            Text("\(yaku.points)")
                .font(.caption2.bold().monospacedDigit())
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(palette.ink.opacity(0.25), in: Capsule())
        }
        .font(.caption2.bold())
        .padding(.leading, 7)
        .padding(.trailing, 4)
        .padding(.vertical, 2)
        // 折り返して複数行になっても左右が丸まりすぎないよう、四隅の角丸にする
        .background(
            palette.badge.opacity(0.85),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .foregroundStyle(palette.ink)
    }
}

/// 明滅する強調枠（選択候補のハイライト用）。
struct PulsingRing: View {
    @Environment(\.koikoiPalette)
    private var palette
    @State private var pulsing = false

    var body: some View {
        CardShape()
            .stroke(palette.highlight, lineWidth: 3)
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
    @Environment(\.koikoiPalette)
    private var palette
    let remaining: Int
    var cardWidth: CGFloat = 40
    /// 札の高さは縦の提案に委ねず比率から確定させる。
    /// 高さが未確定だと盤面が縦に詰まったとき aspectRatio(.fit) が 0 まで潰れ、
    /// 山札が消える（iPhone で束が表示されなかった原因）。
    private var cardHeight: CGFloat { cardWidth / Card.aspectRatio }
    /// 1 枚あたりの積み上がり（縁が見える程度）。
    private let step: CGFloat = 1.1

    var body: some View {
        if remaining > 0 {
            ZStack(alignment: .bottomLeading) {
                ForEach(0..<remaining, id: \.self) { index in
                    CardBack(shadowed: false)
                        .frame(width: cardWidth, height: cardHeight)
                        .offset(x: CGFloat(index) * 0.3, y: -CGFloat(index) * step)
                        .lifted(CGFloat(index) * 0.6)  // visionOS: 実際に厚みが出る
                }
            }
            // 影は 1 枚ごとではなくスタック全体に薄く 1 つだけ落とす
            // （compositingGroup が無いと子ビューごとに影が付き、縁が段々に黒ずむ）
            .compositingGroup()
            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
            .padding(.top, CGFloat(remaining) * step)
            .padding(.trailing, CGFloat(remaining) * 0.3)
            .animation(.default, value: remaining)
        } else {
            CardShape()
                .stroke(palette.ink.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                .frame(width: cardWidth, height: cardHeight)
        }
    }
}

/// 場札 1 枚。
/// - highlighted: 選択候補 / プレビュー手札のマッチ（黄枠・明滅、常に alpha 1）
/// - focused: キーカーソル位置（白枠・太）
/// - dimmed: 場札選択中の候補外（減光）
struct FieldCardView: View {
    @Environment(\.koikoiPalette)
    private var palette
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
                        CardShape()
                            .stroke(palette.ink, lineWidth: 3)
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
    @Environment(\.koikoiPalette)
    private var palette
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
                        CardShape()
                            .stroke(palette.ink, lineWidth: 3)
                            .padding(-3)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if matchCount > 0 {
                        Text("\(matchCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(palette.badgeText)
                            .padding(4)
                            .background(palette.highlight, in: Circle())
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
