import KoikoiCore

/// ID 列から札配列を作る（KoikoiCoreTests と同じ規約のヘルパー）。
func cards(_ ids: Int...) -> [Card] {
    ids.map { Card.all[$0] }
}

func cards(_ ids: [Int]) -> [Card] {
    ids.map { Card.all[$0] }
}
