import KoikoiCore
import SwiftUI

/// 札の裏面（墨地に紅の円）。
public struct CardBack: View {
    public init() {}

    public var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(red: 0.15, green: 0.16, blue: 0.18))
            .overlay {
                Circle()
                    .fill(Color(red: 0.78, green: 0.24, blue: 0.19))
                    .padding(10)
                    .opacity(0.9)
            }
            .aspectRatio(Card.aspectRatio, contentMode: .fit)
    }
}

/// 獲得札の一覧（種類順・小サイズの横スクロール）。
struct CapturedRow: View {
    let cards: [Card]
    let cardWidth: CGFloat

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -cardWidth * 0.4) {
                ForEach(sorted) { card in
                    CardImage(card)
                        .frame(width: cardWidth)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: cardWidth / Card.aspectRatio)
    }

    private var sorted: [Card] {
        cards.sorted { lhs, rhs in
            lhs.type == rhs.type ? lhs.id < rhs.id : lhs.type > rhs.type
        }
    }
}

/// 成立中の役のバッジ列。
struct YakuBadges: View {
    let yakus: [Yaku]

    var body: some View {
        if !yakus.isEmpty {
            HStack(spacing: 6) {
                ForEach(yakus, id: \.self) { yaku in
                    Text("\(yaku.kind.rawValue) \(yaku.points)文")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.85), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

/// 場札 1 枚（選択候補ハイライト付き）。
struct FieldCardView: View {
    let card: Card
    let highlighted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CardImage(card)
                .overlay {
                    if highlighted {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.yellow, lineWidth: 3)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(!highlighted)
    }
}
