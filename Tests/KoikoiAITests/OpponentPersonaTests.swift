import Testing

@testable import KoikoiAI
@testable import KoikoiCore

@Suite struct OpponentPersonaTests {
    @Test func yakuSummaryFormatsList() {
        let summary = OpponentPersona.yakuSummary([Yaku(.sankou, 5), Yaku(.akatan, 6)])
        #expect(summary == "三光(5文)・赤短(6文)")
    }

    @Test func yakuSummaryFallsBackWhenEmpty() {
        #expect(OpponentPersona.yakuSummary([]) == "役")
    }

    @Test func promptsMentionEventDetails() {
        let yakuPrompt = OpponentPersona.prompt(for: .selfYaku([Yaku(.inoshikacho, 5)]))
        #expect(yakuPrompt.contains("猪鹿蝶"))

        let koikoiPrompt = OpponentPersona.prompt(
            for: .selfKoikoi(newYaku: [Yaku(.akatan, 5)], handCount: 3))
        #expect(koikoiPrompt.contains("赤短"))
        #expect(koikoiPrompt.contains("3 枚"))

        let shobuPrompt = OpponentPersona.prompt(for: .playerShobu(points: 12))
        #expect(shobuPrompt.contains("12 文"))
    }

    @Test func allEventsProduceNonEmptyPrompts() {
        let events: [PersonaEvent] = [
            .gameStart, .roundStart(round: 2),
            .selfYaku([Yaku(.kasu, 1)]),
            .selfKoikoi(newYaku: [Yaku(.kasu, 1)], handCount: 1),
            .selfShobu(points: 5),
            .playerYaku([Yaku(.tane, 1)]), .playerKoikoi, .playerShobu(points: 5),
            .roundDrawn,
            .gameEnd(selfWon: true), .gameEnd(selfWon: false), .gameEnd(selfWon: nil)
        ]
        for event in events {
            #expect(!OpponentPersona.prompt(for: event).isEmpty)
        }
    }

    /// モデル不可用時は nil を返し、進行をブロックしない。
    /// （可用環境では生成結果が空でないことだけ確認する）
    @Test func commentNeverBlocksGameplay() async {
        let persona = OpponentPersona()
        let line = await persona.comment(on: .gameStart)
        if OpponentPersona.isAvailable {
            #expect(line == nil || !line!.isEmpty)
        } else {
            #expect(line == nil)
        }
    }
}
