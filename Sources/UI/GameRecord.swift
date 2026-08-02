import Foundation
import KoikoiAI
import KoikoiCore

/// 1 対局の記録（= 1 ファイルの中身）。
/// シードと全指し手から対局を決定的にリプレイできる。
public struct GameRecord: Codable, Sendable, Equatable {
    public var version: Int
    public var rounds: Int
    public var difficulty: Difficulty
    public var seed: UInt64
    /// 適用された全ての手（プレイヤー・AI 双方、適用順）。
    public var moves: [Move]

    public init(rounds: Int, difficulty: Difficulty, seed: UInt64, moves: [Move] = []) {
        version = 1
        self.rounds = rounds
        self.difficulty = difficulty
        self.seed = seed
        self.moves = moves
    }
}
