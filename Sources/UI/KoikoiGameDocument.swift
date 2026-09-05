import SwiftUI
import UniformTypeIdentifiers

public extension UTType {
    /// 対局記録ファイル（.koikoi）。
    static let koikoiGame = UTType(exportedAs: "io.ngs.Koikoi.game")
}

/// 対局記録ファイル（.koikoi）の読み書き。
/// 通常の対局は `GameStore` が自動保存するためユーザーはファイルを意識しないが、
/// visionOS の「保存 / 開く」（fileExporter / fileImporter）ではこの文書型を使う。
public final class KoikoiGameDocument: ReferenceFileDocument {
    public static var readableContentTypes: [UTType] { [.koikoiGame] }

    /// 対局記録。空ファイル（設定前に書き出された文書）では nil。
    @Published public var record: GameRecord?

    public init(record: GameRecord) {
        self.record = record
    }

    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        record = try Self.decode(data)
    }

    /// 空データ = 設定前に書き出された文書（対局記録なし）。
    static func decode(_ data: Data) throws -> GameRecord? {
        data.isEmpty ? nil : try JSONDecoder().decode(GameRecord.self, from: data)
    }

    /// 設定前（nil）でも失敗させず空データを書く。
    static func encode(_ record: GameRecord?) throws -> Data {
        guard let record else { return Data() }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(record)
    }

    public func snapshot(contentType _: UTType) throws -> GameRecord? {
        record
    }

    public func fileWrapper(
        snapshot: GameRecord?, configuration _: WriteConfiguration
    ) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try Self.encode(snapshot))
    }
}
