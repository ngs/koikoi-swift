import Foundation
import KoikoiCore
import XCTest

@testable import KoikoiUI

final class KoikoiGameDocumentTests: XCTestCase {
    /// 新規文書（設定前・record = nil）は空データとして書き出せる。
    /// iOS の DocumentGroup は作成直後に書き出すため、ここで throw すると文書を開けない。
    func testUnconfiguredDocumentEncodesAsEmptyData() throws {
        XCTAssertEqual(try KoikoiGameDocument.encode(nil), Data())
    }

    /// 空データを読むと設定前の文書として復元される。
    func testEmptyDataDecodesAsUnconfigured() throws {
        XCTAssertNil(try KoikoiGameDocument.decode(Data()))
    }

    /// 対局記録はラウンドトリップで保持される。
    func testRecordRoundTrip() throws {
        let record = GameRecord(rounds: 3, difficulty: .normal, seed: 42)
        let data = try KoikoiGameDocument.encode(record)
        XCTAssertEqual(try KoikoiGameDocument.decode(data), record)
    }

    /// 壊れたデータは読み込み失敗として扱う（設定前扱いにしない）。
    func testCorruptDataThrows() {
        XCTAssertThrowsError(try KoikoiGameDocument.decode(Data("not json".utf8)))
    }
}
