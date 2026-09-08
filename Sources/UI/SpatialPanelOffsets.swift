import Foundation

/// visionOS の空間ボードで、ユーザーがドラッグして動かしたパネルの位置。
/// 既定のレイアウト位置からの相対オフセット（メートル）をパネルごとに覚え、
/// 次回起動でも同じ場所にパネルが戻るようにする。
///
/// 保存は `UserDefaults` に JSON 1 本（`koikoi.spatial.panelOffsets`）。
/// 壊れた値・非有限値は既定位置へフォールバックする。
public struct SpatialPanelOffsets: Codable, Equatable, Sendable {
    /// `UserDefaults` の保存先キー。
    public static let storageKey = "koikoi.spatial.panelOffsets"

    /// パネル ID -> 既定位置からのオフセット（メートル）。
    private var offsets: [String: SIMD3<Float>]

    public init() {
        offsets = [:]
    }

    /// パネル 1 枚のオフセット。未設定・非有限値なら nil（= 既定位置）。
    public subscript(id: String) -> SIMD3<Float>? {
        get {
            guard let offset = offsets[id], offset.x.isFinite, offset.y.isFinite, offset.z.isFinite
            else { return nil }
            return offset
        }
        set {
            guard let newValue else {
                offsets.removeValue(forKey: id)
                return
            }
            offsets[id] = newValue
        }
    }

    /// 1 枚も動かされていないか（リセットボタンの要否判定に使う）。
    public var isEmpty: Bool { offsets.isEmpty }

    // MARK: - 符号化

    /// 保存用の JSON（符号化できないときは nil）。
    public func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// 保存された JSON から復元する（無い / 壊れていれば既定位置）。
    public static func decoded(_ data: Data?) -> SpatialPanelOffsets {
        guard let data, let value = try? JSONDecoder().decode(Self.self, from: data) else {
            return SpatialPanelOffsets()
        }
        return value
    }

    // MARK: - 保存先

    public static func load(from defaults: UserDefaults = .standard) -> SpatialPanelOffsets {
        decoded(defaults.data(forKey: storageKey))
    }

    public func save(to defaults: UserDefaults = .standard) {
        guard let data = encoded() else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// 全パネルを既定位置に戻す。
    public static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
