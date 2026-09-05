import Foundation
import KoikoiCore

/// 進行中の対局を 1 つだけ保持する保存先。
/// ユーザーにファイルを意識させず、起動時に自動復元するために使う
/// （文書ブラウザ / DocumentGroup の置き換え）。
@MainActor
public final class GameStore {
    /// アプリ共有のストア（Application Support/Koikoi/current.koikoi）。
    public static let shared = GameStore(directory: GameStore.defaultDirectory)

    private let directory: URL

    /// 保存先ディレクトリを注入する（テストでは一時ディレクトリを渡す）。
    public init(directory: URL) {
        self.directory = directory
    }

    private static var defaultDirectory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Koikoi", isDirectory: true)
    }

    var fileURL: URL {
        directory.appendingPathComponent("current.koikoi")
    }

    /// 保存済みの対局。無い / 壊れている場合は nil（壊れていればファイルを捨てる）。
    public func load() -> GameRecord? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            return try KoikoiGameDocument.decode(data)
        } catch {
            clear()
            return nil
        }
    }

    /// 対局を原子的に書き出す（数 KB なので同期で十分）。
    public func save(_ record: GameRecord) {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try KoikoiGameDocument.encode(record).write(to: fileURL, options: .atomic)
        } catch {
            // 保存に失敗しても対局の進行は止めない
        }
    }

    /// 保存済みの対局を捨てる（対局終了・中断時）。
    public func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
