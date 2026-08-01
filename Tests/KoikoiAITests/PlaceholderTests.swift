import Testing

@testable import KoikoiAI

@Suite struct PlaceholderTests {
    @Test func modulePresent() {
        _ = KoikoiAIModule.self
    }
}
