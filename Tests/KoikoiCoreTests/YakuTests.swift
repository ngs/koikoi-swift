import Testing

@testable import KoikoiCore

/// ID 列から札配列を作る（go-koikoi の yaku_test.go の cardsByIDs に対応）。
func cards(_ ids: Int...) -> [Card] {
    ids.compactMap(Card.card(id:))
}

func cards(_ ids: [Int]) -> [Card] {
    ids.compactMap(Card.card(id:))
}

@Suite struct YakuTests {
    private func yaku(_ yakus: [Yaku], _ kind: YakuKind) -> Yaku? {
        yakus.first { $0.kind == kind }
    }

    // MARK: - 光系

    @Test func gokou() {
        let yakus = YakuChecker.checkYaku(captured: cards(0, 8, 28, 40, 44))
        #expect(yaku(yakus, .gokou)?.points == 10)
        #expect(yaku(yakus, .shikou) == nil)
        #expect(yaku(yakus, .ameShikou) == nil)
        #expect(yaku(yakus, .sankou) == nil)
    }

    @Test func shikou() {
        let yakus = YakuChecker.checkYaku(captured: cards(0, 8, 28, 44))
        #expect(yaku(yakus, .shikou)?.points == 8)
        #expect(yaku(yakus, .gokou) == nil)
        #expect(yaku(yakus, .sankou) == nil)
    }

    @Test func ameShikou() {
        // 柳(40) + 光3枚
        let yakus = YakuChecker.checkYaku(captured: cards(0, 8, 28, 40))
        #expect(yaku(yakus, .ameShikou)?.points == 7)
        #expect(yaku(yakus, .shikou) == nil)
        #expect(yaku(yakus, .sankou) == nil)
    }

    @Test func sankou() {
        let yakus = YakuChecker.checkYaku(captured: cards(0, 8, 28))
        #expect(yaku(yakus, .sankou)?.points == 5)
    }

    /// 柳 + 光2枚は三光にならない（柳は三光に数えない）。
    @Test func sankouWithYanagiNotCounted() {
        let yakus = YakuChecker.checkYaku(captured: cards(0, 8, 40))
        #expect(yaku(yakus, .sankou) == nil)
        #expect(yaku(yakus, .ameShikou) == nil)
    }

    /// 光系の排他制御（五光 > 四光 > 雨四光 > 三光）。
    @Test func hikariExclusivity() {
        // 五光時は他の光役なし
        let gokou = YakuChecker.checkYaku(captured: cards(0, 8, 28, 40, 44))
        #expect(gokou.count(where: { [.gokou, .shikou, .ameShikou, .sankou].contains($0.kind) }) == 1)
        // 雨四光時（柳含む4枚）は三光にしない
        let ame = YakuChecker.checkYaku(captured: cards(0, 8, 40, 44))
        #expect(yaku(ame, .ameShikou) != nil)
        #expect(yaku(ame, .sankou) == nil)
    }

    // MARK: - 猪鹿蝶・花見・月見

    @Test func inoshikacho() {
        let yakus = YakuChecker.checkYaku(captured: cards(20, 24, 36))
        #expect(yaku(yakus, .inoshikacho)?.points == 5)
        #expect(yaku(yakus, .tane) == nil)
    }

    /// 猪鹿蝶 + 追加の種札で +1 文ずつ。
    @Test func inoshikachoExtra() {
        let yakus = YakuChecker.checkYaku(captured: cards(20, 24, 36, 4, 12))
        #expect(yaku(yakus, .inoshikacho)?.points == 7)
    }

    @Test func hanamiDeIppai() {
        let yakus = YakuChecker.checkYaku(captured: cards(8, 32))
        #expect(yaku(yakus, .hanami)?.points == 5)
    }

    @Test func tsukimiDeIppai() {
        let yakus = YakuChecker.checkYaku(captured: cards(28, 32))
        #expect(yaku(yakus, .tsukimi)?.points == 5)
    }

    // MARK: - 短冊系

    @Test func akatan() {
        let yakus = YakuChecker.checkYaku(captured: cards(1, 5, 9))
        #expect(yaku(yakus, .akatan)?.points == 5)
        #expect(yaku(yakus, .tan) == nil)
    }

    @Test func akatanExtra() {
        let yakus = YakuChecker.checkYaku(captured: cards(1, 5, 9, 13))
        #expect(yaku(yakus, .akatan)?.points == 6)
    }

    @Test func aotan() {
        let yakus = YakuChecker.checkYaku(captured: cards(21, 33, 37))
        #expect(yaku(yakus, .aotan)?.points == 5)
    }

    @Test func aotanExtra() {
        let yakus = YakuChecker.checkYaku(captured: cards(21, 33, 37, 17))
        #expect(yaku(yakus, .aotan)?.points == 6)
    }

    @Test func akatanAotanOverlap() {
        let yakus = YakuChecker.checkYaku(captured: cards(1, 5, 9, 21, 33, 37))
        #expect(yaku(yakus, .akatanAotan)?.points == 10)
        #expect(yaku(yakus, .akatan) == nil)
        #expect(yaku(yakus, .aotan) == nil)
        #expect(yaku(yakus, .tan) == nil)
    }

    @Test func akatanAotanOverlapExtra() {
        let yakus = YakuChecker.checkYaku(captured: cards(1, 5, 9, 21, 33, 37, 13))
        #expect(yaku(yakus, .akatanAotan)?.points == 11)
    }

    // MARK: - 枚数役

    @Test func tane() {
        let yakus = YakuChecker.checkYaku(captured: cards(4, 12, 16, 29, 32))
        #expect(yaku(yakus, .tane)?.points == 1)
    }

    @Test func taneExtra() {
        let yakus = YakuChecker.checkYaku(captured: cards(4, 12, 16, 29, 32, 41))
        #expect(yaku(yakus, .tane)?.points == 2)
    }

    /// 猪鹿蝶が成立したらタネは無効。
    @Test func taneDisabledByInoshikacho() {
        let yakus = YakuChecker.checkYaku(captured: cards(20, 24, 36, 4, 12))
        #expect(yaku(yakus, .tane) == nil)
        #expect(yaku(yakus, .inoshikacho) != nil)
    }

    @Test func tan() {
        let yakus = YakuChecker.checkYaku(captured: cards(13, 17, 25, 42, 1))
        #expect(yaku(yakus, .tan)?.points == 1)
    }

    /// 赤短が成立したらタンは無効。
    @Test func tanDisabledByAkatan() {
        let yakus = YakuChecker.checkYaku(captured: cards(1, 5, 9, 13, 17))
        #expect(yaku(yakus, .tan) == nil)
        #expect(yaku(yakus, .akatan)?.points == 7)
    }

    /// 青短が成立したらタンは無効。
    @Test func tanDisabledByAotan() {
        let yakus = YakuChecker.checkYaku(captured: cards(21, 33, 37, 13, 17))
        #expect(yaku(yakus, .tan) == nil)
        #expect(yaku(yakus, .aotan)?.points == 7)
    }

    @Test func kasu() {
        let yakus = YakuChecker.checkYaku(captured: cards(2, 3, 6, 7, 10, 11, 14, 15, 18, 19))
        #expect(yaku(yakus, .kasu)?.points == 1)
    }

    @Test func kasuExtra() {
        let yakus = YakuChecker.checkYaku(captured: cards(2, 3, 6, 7, 10, 11, 14, 15, 18, 19, 22, 23))
        #expect(yaku(yakus, .kasu)?.points == 3)
    }

    // MARK: - 役なし・複合

    @Test func noYaku() {
        #expect(YakuChecker.checkYaku(captured: cards(0, 4, 2)).isEmpty)
    }

    @Test func emptyCaptured() {
        #expect(YakuChecker.checkYaku(captured: []).isEmpty)
    }

    /// 複数役の同時成立。
    @Test func multipleYaku() {
        // 三光 + 赤短
        let yakus = YakuChecker.checkYaku(captured: cards(0, 8, 28, 1, 5, 9))
        #expect(yaku(yakus, .sankou)?.points == 5)
        #expect(yaku(yakus, .akatan)?.points == 5)
        #expect(YakuChecker.totalPoints(yakus) == 10)
    }

    @Test func totalPoints() {
        #expect(YakuChecker.totalPoints([]) == 0)
        #expect(YakuChecker.totalPoints([Yaku(.gokou, 10), Yaku(.akatan, 5)]) == 15)
    }
}

@Suite struct YakuReachTests {
    private func reach(_ reaches: [YakuReach], _ kind: YakuKind) -> YakuReach? {
        reaches.first { $0.kind == kind }
    }

    @Test func gokouReach() {
        // 光4枚 → 五光リーチ（不足は桐に鳳凰(44)）
        let reaches = YakuChecker.checkReach(captured: cards(0, 8, 28, 40), opponentCaptured: [])
        #expect(reach(reaches, .gokou)?.missing == cards(44))
    }

    @Test func shikouReach() {
        // 柳以外の光3枚（三光成立中）→ 四光リーチ（不足は桐(44)）
        let reaches = YakuChecker.checkReach(captured: cards(0, 8, 28), opponentCaptured: [])
        #expect(reach(reaches, .shikou)?.missing == cards(44))
    }

    @Test func ameShikouReachFromSankou() {
        // 三光成立中（柳以外3枚）→ 柳を取れば雨四光
        let reaches = YakuChecker.checkReach(captured: cards(0, 8, 28), opponentCaptured: [])
        #expect(reach(reaches, .ameShikou)?.missing == cards(40))
    }

    @Test func ameShikouReachWithYanagi() {
        let reaches = YakuChecker.checkReach(captured: cards(0, 8, 40), opponentCaptured: [])
        let missing = reach(reaches, .ameShikou)?.missing
        #expect(missing == cards(28, 44))
    }

    @Test func sankouReach() {
        let reaches = YakuChecker.checkReach(captured: cards(0, 8), opponentCaptured: [])
        #expect(reach(reaches, .sankou)?.missing == cards(28, 44))
    }

    /// 柳持ちは三光リーチにならない。
    @Test func sankouReachNotWithYanagi() {
        let reaches = YakuChecker.checkReach(captured: cards(0, 40), opponentCaptured: [])
        #expect(reach(reaches, .sankou) == nil)
    }

    @Test func inoshikachoReach() {
        // 萩に猪(24)・紅葉に鹿(36) → 不足は牡丹に蝶(20)
        let reaches = YakuChecker.checkReach(captured: cards(24, 36), opponentCaptured: [])
        #expect(reach(reaches, .inoshikacho)?.missing == cards(20))
    }

    @Test func hanamiReach() {
        let reaches = YakuChecker.checkReach(captured: cards(8), opponentCaptured: [])
        #expect(reach(reaches, .hanami)?.missing == cards(32))
    }

    @Test func tsukimiReach() {
        let reaches = YakuChecker.checkReach(captured: cards(28), opponentCaptured: [])
        #expect(reach(reaches, .tsukimi)?.missing == cards(32))
    }

    @Test func akatanReach() {
        let reaches = YakuChecker.checkReach(captured: cards(1, 5), opponentCaptured: [])
        #expect(reach(reaches, .akatan)?.missing == cards(9))
    }

    @Test func aotanReach() {
        let reaches = YakuChecker.checkReach(captured: cards(21, 33), opponentCaptured: [])
        #expect(reach(reaches, .aotan)?.missing == cards(37))
    }

    /// 赤短成立中に青短あと1枚 → 重複リーチ。
    @Test func akatanAotanOverlapFromAkatan() {
        let reaches = YakuChecker.checkReach(captured: cards(1, 5, 9, 21, 33), opponentCaptured: [])
        #expect(reach(reaches, .akatanAotan)?.missing == cards(37))
        #expect(reach(reaches, .aotan) == nil)
    }

    /// 青短成立中に赤短あと1枚 → 重複リーチ。
    @Test func akatanAotanOverlapFromAotan() {
        let reaches = YakuChecker.checkReach(captured: cards(21, 33, 37, 1, 5), opponentCaptured: [])
        #expect(reach(reaches, .akatanAotan)?.missing == cards(9))
        #expect(reach(reaches, .akatan) == nil)
    }

    @Test func taneReach() {
        let reaches = YakuChecker.checkReach(captured: cards(4, 12, 16, 29), opponentCaptured: [])
        let taneReach = reach(reaches, .tane)
        #expect(taneReach != nil)
        #expect(taneReach?.missing == nil)
    }

    @Test func tanReach() {
        let reaches = YakuChecker.checkReach(captured: cards(13, 17, 25, 42), opponentCaptured: [])
        #expect(reach(reaches, .tan) != nil)
    }

    @Test func kasuReach() {
        let reaches = YakuChecker.checkReach(
            captured: cards(2, 3, 6, 7, 10, 11, 14, 15, 18), opponentCaptured: [])
        #expect(reach(reaches, .kasu) != nil)
    }

    @Test func noReach() {
        let reaches = YakuChecker.checkReach(captured: cards(0, 4), opponentCaptured: [])
        #expect(reach(reaches, .gokou) == nil)
        #expect(reach(reaches, .inoshikacho) == nil)
    }

    /// 成立済みの役はリーチに出ない。
    @Test func alreadyComplete() {
        let reaches = YakuChecker.checkReach(captured: cards(20, 24, 36), opponentCaptured: [])
        #expect(reach(reaches, .inoshikacho) == nil)
    }

    @Test func emptyCaptured() {
        #expect(YakuChecker.checkReach(captured: [], opponentCaptured: []).isEmpty)
    }

    // MARK: - 相手獲得札による除外

    /// 不足札が相手に取られていたらリーチにしない（花見）。
    @Test func excludesOpponentCapturedHanami() {
        let reaches = YakuChecker.checkReach(captured: cards(8), opponentCaptured: cards(32))
        #expect(reach(reaches, .hanami) == nil)
    }

    /// 同（月見）。
    @Test func excludesOpponentCapturedTsukimi() {
        let reaches = YakuChecker.checkReach(captured: cards(28), opponentCaptured: cards(32))
        #expect(reach(reaches, .tsukimi) == nil)
    }

    /// 同（猪鹿蝶）。
    @Test func excludesOpponentCapturedInoshikacho() {
        let reaches = YakuChecker.checkReach(captured: cards(20, 24), opponentCaptured: cards(36))
        #expect(reach(reaches, .inoshikacho) == nil)
    }

    /// 相手が不足札を持っていなければリーチになる。
    @Test func allowsWhenOpponentDoesNotHaveMissing() {
        let reaches = YakuChecker.checkReach(captured: cards(8), opponentCaptured: cards(0, 4))
        #expect(reach(reaches, .hanami)?.missing == cards(32))
    }

    // MARK: - どちらも持っていない場合はリーチにしない

    @Test func noReachWhenPlayerHasNeitherHanamiCard() {
        let reaches = YakuChecker.checkReach(captured: cards(0, 4), opponentCaptured: [])
        #expect(reach(reaches, .hanami) == nil)
    }

    @Test func noReachWhenPlayerHasNeitherTsukimiCard() {
        let reaches = YakuChecker.checkReach(captured: cards(0, 4), opponentCaptured: [])
        #expect(reach(reaches, .tsukimi) == nil)
    }

    @Test func noReachWhenPlayerHasNoInoshikachoCards() {
        let reaches = YakuChecker.checkReach(captured: cards(4, 12), opponentCaptured: [])
        #expect(reach(reaches, .inoshikacho) == nil)
    }

    @Test func noReachWhenPlayerHasOnlyOneInoshikachoCard() {
        let reaches = YakuChecker.checkReach(captured: cards(20), opponentCaptured: [])
        #expect(reach(reaches, .inoshikacho) == nil)
    }

    @Test func noReachWhenPlayerHasNoAkatanCards() {
        let reaches = YakuChecker.checkReach(captured: cards(13, 17), opponentCaptured: [])
        #expect(reach(reaches, .akatan) == nil)
    }

    @Test func noReachWhenPlayerHasNoAotanCards() {
        let reaches = YakuChecker.checkReach(captured: cards(13, 17), opponentCaptured: [])
        #expect(reach(reaches, .aotan) == nil)
    }
}
