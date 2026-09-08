import Foundation
import Testing

@testable import KoikoiUI

/// visionOS の空間ボードで動かしたパネル位置の保存（`koikoi.spatial.panelOffsets`）。
@Suite struct SpatialPanelOffsetsTests {
    private func makeDefaults() throws -> UserDefaults {
        let name = "io.ngs.Koikoi.tests.\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: name))
    }

    @Test func newValueIsEmpty() {
        let offsets = SpatialPanelOffsets()
        #expect(offsets.isEmpty)
        #expect(offsets["scoreboard"] == nil)
    }

    /// 書いた値がそのまま読める。nil を入れると既定位置に戻る。
    @Test func subscriptStoresAndRemoves() {
        var offsets = SpatialPanelOffsets()
        offsets["scoreboard"] = SIMD3<Float>(0.1, -0.05, 0.2)
        #expect(offsets["scoreboard"] == SIMD3<Float>(0.1, -0.05, 0.2))
        #expect(!offsets.isEmpty)
        offsets["scoreboard"] = nil
        #expect(offsets["scoreboard"] == nil)
        #expect(offsets.isEmpty)
    }

    /// JSON へ書いて読み戻すと同じ値になる。
    @Test func encodingRoundTrips() throws {
        var offsets = SpatialPanelOffsets()
        offsets["yakuPlayer"] = SIMD3<Float>(-0.2, 0.15, 0.05)
        offsets["yakuOpponent"] = SIMD3<Float>(0, 0, -0.3)
        let data = try #require(offsets.encoded())
        #expect(SpatialPanelOffsets.decoded(data) == offsets)
    }

    /// 無い / 壊れたデータは既定位置（空）にフォールバックする。
    @Test func decodingUnusableDataFallsBackToDefaults() {
        #expect(SpatialPanelOffsets.decoded(nil).isEmpty)
        #expect(SpatialPanelOffsets.decoded(Data("not json".utf8)).isEmpty)
    }

    /// 非有限値は保存されても既定位置として扱う（NaN でパネルが消えない）。
    @Test func nonFiniteOffsetsAreIgnored() {
        var offsets = SpatialPanelOffsets()
        offsets["scoreboard"] = SIMD3<Float>(.nan, 0, 0)
        #expect(offsets["scoreboard"] == nil)
        offsets["yakuPlayer"] = SIMD3<Float>(0, .infinity, 0)
        #expect(offsets["yakuPlayer"] == nil)
    }

    /// UserDefaults への保存・読み出し・リセット。
    @Test func savesAndClearsInUserDefaults() throws {
        let defaults = try makeDefaults()
        #expect(SpatialPanelOffsets.load(from: defaults).isEmpty)

        var offsets = SpatialPanelOffsets()
        offsets["scoreboard"] = SIMD3<Float>(0.25, 0.1, 0)
        offsets.save(to: defaults)
        #expect(SpatialPanelOffsets.load(from: defaults) == offsets)

        SpatialPanelOffsets.clear(in: defaults)
        #expect(SpatialPanelOffsets.load(from: defaults).isEmpty)
    }
}
