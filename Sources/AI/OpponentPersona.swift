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
        You are Koi, the opponent in a game of hanafuda koi-koi: a witty, \
        rakish character who speaks like an old Edo townsman. Unruffled \
        whether winning or losing, and given to light remarks about the \
        cards and the season.
        """

    private let instructions: String
    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif

    /// - Parameters:
    ///   - character: 人格の設定文。
    ///   - language: 台詞を返させる言語（既定は現在のロケール。
    ///     プロンプト自体は英語のまま、応答の言語だけを指定する）。
    public init(
        character: String = OpponentPersona.defaultCharacter,
        language: Locale.Language = Locale.current.language
    ) {
        instructions = """
            \(character)

            Reply with a single line of dialogue in \
            \(Self.languageName(of: language)), about 30 characters or fewer. \
            No explanation, quotation marks, or emoji.
            """
    }

    /// 言語コードを英語の言語名にする（プロンプトに埋める用）。
    static func languageName(of language: Locale.Language) -> String {
        let code = language.languageCode?.identifier ?? "en"
        return Locale(identifier: "en_US").localizedString(forLanguageCode: code) ?? "English"
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
        let decision = declaredKoikoi ? "called koi-koi" : "chose to stop"
        return await respond(to: """
            You made \(names) and, with \(handCount) cards left in hand, \
            \(decision). Say a word in character about that choice.
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
            return "The match begins. Give an opening greeting in one line."
        case .roundStart(let round):
            return "Round \(round) begins. Say a word about your resolve."
        case .selfYaku(let yakus):
            return "You made \(yakuSummary(yakus)). Say a word of delight."
        case let .selfKoikoi(newYaku, handCount):
            return "You made \(yakuSummary(newYaku)) but called koi-koi with " +
                "\(handCount) cards left in hand. Say something bold."
        case .selfShobu(let points):
            return "You stopped and took the round for \(points) points. Say your catchphrase."
        case .playerYaku(let yakus):
            return "Your opponent made \(yakuSummary(yakus)). Say a word of frustration."
        case .playerKoikoi:
            return "Your opponent called koi-koi. Answer the provocation in one line."
        case .playerShobu(let points):
            return "Your opponent took the round for \(points) points. Be a sore loser in one line."
        case .roundDrawn:
            return "The round was a draw. Give a brief remark."
        case .gameEnd(let selfWon):
            switch selfWon {
            case .some(true): return "You won the match. Give a closing greeting in one line."
            case .some(false):
                return "You lost the match. Give a gracious closing greeting in one line."
            case .none: return "The match was drawn. Give a closing greeting in one line."
            }
        }
    }

    /// 役リストを「Five Brights (10 pts) · Red Poetry Ribbons (5 pts)」形式に要約する。
    static func yakuSummary(_ yakus: [Yaku]) -> String {
        guard !yakus.isEmpty else { return "a yaku" }
        return yakus
            .map { "\($0.kind.displayName) (\($0.points) pts)" }
            .joined(separator: " · ")
    }
}
