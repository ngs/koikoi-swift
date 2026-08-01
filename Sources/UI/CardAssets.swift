import KoikoiCore
import SwiftUI

public extension Card {
    /// Cards.xcassets 内の imageset 名（`{id:02d}_{slug}` 形式・ID 順）。
    var assetName: String {
        Self.assetNames[id]
    }

    /// 実物の札の縦横比（約 5.4:8.7。スプライト原寸 748×1200 に一致）。
    static let aspectRatio: CGFloat = 748.0 / 1_200.0

    private static let assetNames = [
        "00_matsu_tsuru", "01_matsu_akatan", "02_matsu_kasu1", "03_matsu_kasu2",
        "04_ume_uguisu", "05_ume_akatan", "06_ume_kasu1", "07_ume_kasu2",
        "08_sakura_maku", "09_sakura_akatan", "10_sakura_kasu1", "11_sakura_kasu2",
        "12_fuji_hototogisu", "13_fuji_tanzaku", "14_fuji_kasu1", "15_fuji_kasu2",
        "16_ayame_yatsuhashi", "17_ayame_tanzaku", "18_ayame_kasu1", "19_ayame_kasu2",
        "20_botan_cho", "21_botan_aotan", "22_botan_kasu1", "23_botan_kasu2",
        "24_hagi_inoshishi", "25_hagi_tanzaku", "26_hagi_kasu1", "27_hagi_kasu2",
        "28_susuki_tsuki", "29_susuki_kari", "30_susuki_kasu1", "31_susuki_kasu2",
        "32_kiku_sakazuki", "33_kiku_aotan", "34_kiku_kasu1", "35_kiku_kasu2",
        "36_momiji_shika", "37_momiji_aotan", "38_momiji_kasu1", "39_momiji_kasu2",
        "40_yanagi_michikaze", "41_yanagi_tsubame", "42_yanagi_tanzaku", "43_yanagi_kasu",
        "44_kiri_hoo", "45_kiri_kasu1", "46_kiri_kasu2", "47_kiri_kasu3"
    ]
}

/// 札 1 枚の表面。実物比率を保ち、角丸で描画する。
public struct CardImage: View {
    public let card: Card

    public init(_ card: Card) {
        self.card = card
    }

    public var body: some View {
        // 札画像はアプリの Assets.xcassets/Cards（メインバンドル）から解決する
        Image(card.assetName)
            .resizable()
            .aspectRatio(Card.aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel(Text(card.name))
    }
}

#Preview("札一覧") {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            ForEach(Card.all) { card in
                CardImage(card)
            }
        }
        .padding()
    }
}
