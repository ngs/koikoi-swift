import Foundation
import Testing

@testable import KoikoiAI
@testable import KoikoiCore

@Suite struct OpponentPersonaTests {
    @Test func yakuSummaryFormatsList() {
        let summary = OpponentPersona.yakuSummary(
            [Yaku(.threeBrights, 5), Yaku(.redPoetryRibbons, 6)])
        #expect(summary == "Three Brights (5 pts) · Red Poetry Ribbons (6 pts)")
    }

    @Test func yakuSummaryFallsBackWhenEmpty() {
        #expect(OpponentPersona.yakuSummary([]) == "a yaku")
    }

    /// 台詞の言語だけをロケールから決める（プロンプト自体は英語）。
    @Test func responseLanguageFollowsLocale() {
        #expect(OpponentPersona.languageName(of: Locale.Language(identifier: "ja")) == "Japanese")
        #expect(OpponentPersona.languageName(of: Locale.Language(identifier: "en")) == "English")
    }

    @Test func promptsMentionEventDetails() {
        let yakuPrompt = OpponentPersona.prompt(for: .selfYaku([Yaku(.boarDeerButterfly, 5)]))
        #expect(yakuPrompt.contains("Boar, Deer, Butterfly"))

        let koikoiPrompt = OpponentPersona.prompt(
            for: .selfKoikoi(newYaku: [Yaku(.redPoetryRibbons, 5)], handCount: 3))
        #expect(koikoiPrompt.contains("Red Poetry Ribbons"))
        #expect(koikoiPrompt.contains("3 cards"))

        let shobuPrompt = OpponentPersona.prompt(for: .playerShobu(points: 12))
        #expect(shobuPrompt.contains("12 points"))
    }

    @Test func allEventsProduceNonEmptyPrompts() {
        let events: [PersonaEvent] = [
            .gameStart, .roundStart(round: 2),
            .selfYaku([Yaku(.chaff, 1)]),
            .selfKoikoi(newYaku: [Yaku(.chaff, 1)], handCount: 1),
            .selfShobu(points: 5),
            .playerYaku([Yaku(.animals, 1)]), .playerKoikoi, .playerShobu(points: 5),
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
