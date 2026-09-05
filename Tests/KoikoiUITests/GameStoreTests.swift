import Foundation
import KoikoiCore
import XCTest

@testable import KoikoiUI

@MainActor
final class GameStoreTests: XCTestCase {
    private var directory = URL(fileURLWithPath: NSTemporaryDirectory())

    override func setUp() {
        super.setUp()
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GameStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    /// 保存前は復元するものが無い。
    func testLoadReturnsNilWhenNothingSaved() {
        XCTAssertNil(GameStore(directory: directory).load())
    }

    /// 保存した対局はそのまま復元される。
    func testSaveThenLoadRoundTrip() {
        let store = GameStore(directory: directory)
        let record = GameRecord(rounds: 3, difficulty: .hard, seed: 42)
        store.save(record)
        XCTAssertEqual(store.load(), record)
    }

    /// 対局をやめたら保存は消える。
    func testClearRemovesSavedGame() {
        let store = GameStore(directory: directory)
        store.save(GameRecord(rounds: 3, difficulty: .normal, seed: 7))
        store.clear()
        XCTAssertNil(store.load())
    }

    /// 壊れた保存データは復元せず捨てる（次の起動を壊さない）。
    func testCorruptDataIsDiscarded() throws {
        let store = GameStore(directory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.fileURL)
        XCTAssertNil(store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
    }
}
