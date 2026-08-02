import Foundation
import Observation

/// visionOS の空間ボードウィンドウと 2D 文書ウィンドウの間で
/// 進行中の対局（ビューモデル）を共有するための置き場。
@MainActor
@Observable
public final class SpatialSession {
    public static let shared = SpatialSession()

    /// 空間ボードに表示する対局。nil なら未開始。
    public var model: GameViewModel?

    private init() {}
}
