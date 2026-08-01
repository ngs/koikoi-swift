import Foundation
import KoikoiCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 対戦相手の台詞を生成するきっかけとなるイベント（相手 AI 視点）。
public enum PersonaEvent: Sendable, Hashable {
    case gameStart
    case roundStart(round: Int)
    /// 自分（AI）が役を作った。
    case selfYaku([Yaku])
    /// 自分（AI）がこいこいを選んだ。
    case selfKoikoi(newYaku: [Yaku], handCount: Int)
    /// 自分（AI）が勝負して上がった。
    case selfShobu(points: Int)
    /// プレイヤーが役を作った。
    case playerYaku([Yaku])
    /// プレイヤーがこいこいした。
    case playerKoikoi
    /// プレイヤーが勝負して上がった。
    case playerShobu(points: Int)
    /// 流局。
    case roundDrawn
    /// 対局終了。nil は引き分け。
    case gameEnd(selfWon: Bool?)
}

/// FoundationModels によるオンデバイス人格。
/// 台詞やこいこい判断の説明を生成する。モデル不可用・生成失敗時は
/// 必ず nil を返し、ゲーム進行を LLM 応答でブロックしない。
public actor OpponentPersona {
    /// 既定の人格設定。
    public static let defaultCharacter = """
        あなたは花札こいこいの対戦相手「こい」。粋でいなせな江戸言葉の \
        キャラクター。勝っても負けても飄々としていて、札や季節の風情に \
        さらりと触れる。
        """

    private let instructions: String
    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif

    public init(character: String = OpponentPersona.defaultCharacter) {
        instructions = """
            \(character)

            出力は台詞 1 文のみ（最大 30 文字程度）。説明・引用符・絵文字は \
            付けない。日本語で答える。
            """
    }

    /// オンデバイスモデルが利用可能か。
    public static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
        #else
        return false
        #endif
    }

    /// イベントに対する一言を生成する。不可用・失敗時は nil。
    public func comment(on event: PersonaEvent) async -> String? {
        await respond(to: Self.prompt(for: event))
    }

    /// こいこい判断の理由をひとこと説明する（探索が決めた選択の言語化）。
    public func koikoiRationale(
        newYaku: [Yaku], declaredKoikoi: Bool, handCount: Int
    ) async -> String? {
        let names = Self.yakuSummary(newYaku)
        let decision = declaredKoikoi ? "こいこいを選んだ" : "勝負を選んだ"
        return await respond(to: """
            \(names)が成立し、残り手札 \(handCount) 枚で\(decision)。 \
            その心意気をキャラクターとして一言で。
            """)
    }

    /// セッションを事前に温める（初回応答の遅延対策・任意）。
    public func prewarm() {
        #if canImport(FoundationModels)
        guard Self.isAvailable else { return }
        ensureSession().prewarm()
        #endif
    }

    // MARK: - 内部

    private func respond(to prompt: String) async -> String? {
        #if canImport(FoundationModels)
        guard Self.isAvailable else { return nil }
        do {
            let response = try await ensureSession().respond(to: prompt)
            let line = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return line.isEmpty ? nil : line
        } catch {
            // 生成失敗は無言で進行（台詞は装飾であってゲームを止めない）
            return nil
        }
        #else
        return nil
        #endif
    }

    #if canImport(FoundationModels)
    private func ensureSession() -> LanguageModelSession {
        if let session {
            return session
        }
        let created = LanguageModelSession(instructions: instructions)
        session = created
        return created
    }
    #endif

    /// イベントからプロンプト文を組み立てる（純粋関数・テスト用に分離）。
    static func prompt(for event: PersonaEvent) -> String {
        switch event {
        case .gameStart:
            return "対局開始。最初のあいさつを一言で。"
        case .roundStart(let round):
            return "第 \(round) ラウンド開始。意気込みを一言で。"
        case .selfYaku(let yakus):
            return "自分に\(yakuSummary(yakus))が成立した。喜びを一言で。"
        case let .selfKoikoi(newYaku, handCount):
            return "自分に\(yakuSummary(newYaku))が成立したが、残り手札 \(handCount) 枚で" +
                "こいこいを宣言した。強気の一言を。"
        case .selfShobu(let points):
            return "勝負して \(points) 文で上がった。決め台詞を一言で。"
        case .playerYaku(let yakus):
            return "相手（プレイヤー）に\(yakuSummary(yakus))が成立した。悔しさを一言で。"
        case .playerKoikoi:
            return "相手（プレイヤー）がこいこいを宣言した。挑発を受けた一言を。"
        case .playerShobu(let points):
            return "相手（プレイヤー）が \(points) 文で上がった。負け惜しみを一言で。"
        case .roundDrawn:
            return "流局した。ひとこと感想を。"
        case .gameEnd(let selfWon):
            switch selfWon {
            case .some(true): return "対局に勝った。締めのあいさつを一言で。"
            case .some(false): return "対局に負けた。潔い締めのあいさつを一言で。"
            case .none: return "対局は引き分けだった。締めのあいさつを一言で。"
            }
        }
    }

    /// 役リストを「五光(10文)・赤短(5文)」形式に要約する。
    static func yakuSummary(_ yakus: [Yaku]) -> String {
        guard !yakus.isEmpty else { return "役" }
        return yakus
            .map { "\($0.kind.rawValue)(\($0.points)文)" }
            .joined(separator: "・")
    }
}
