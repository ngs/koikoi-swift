import KoikoiCore

/// Decides, for one sync of the visionOS spatial board, the order in which cards move and
/// which captured field card each moving card pairs with. A moving card (from the hand,
/// the opponent's hand, or the deck) flies to a captured field card of the same month,
/// meets it, and the two travel to the captured panel together.
///
/// Only the decision lives here, free of RealityKit, so SPM tests can exercise it.
/// `BoardScene` turns the result into `Transform` legs.
public struct SpatialCapturePlanner: Equatable, Sendable {
    /// What one moving card does.
    public enum Step: Equatable, Sendable {
        /// Fly to the field card `mate` after `at` seconds, then travel with it to the panel.
        case meet(mate: Int, at: Double)
        /// No mate to meet; go straight to the destination after `at` seconds.
        case direct(at: Double)
    }

    /// Time between meeting the mate and leaving for the captured panel.
    public static let meetDuration = 0.55
    /// Length of one move that includes a meeting.
    public static let captureStepDuration = 1.0
    /// Length of one move without a meeting.
    public static let directStepDuration = 0.5

    /// Cards captured in this sync.
    private let newlyCaptured: Set<Int>
    /// Cards that went from the field to a captured pile in this sync (mate candidates).
    private let fieldToCaptured: [Int]

    /// Moving card -> its step.
    public private(set) var steps: [Int: Step] = [:]
    /// Field card heading to the captured panel -> when it leaves.
    public private(set) var landings: [Int: Double] = [:]
    /// When the next move starts.
    public private(set) var clock = 0.0

    public init(newlyCaptured: Set<Int>, fieldToCaptured: [Int]) {
        self.newlyCaptured = newlyCaptured
        self.fieldToCaptured = fieldToCaptured
    }

    /// Field cards already paired with a moving card.
    public var consumed: Set<Int> {
        Set(landings.keys)
    }

    /// If `id` was captured, a same-month field card nobody has paired with yet.
    public func partner(of id: Int) -> Int? {
        guard newlyCaptured.contains(id), let month = Card.card(id: id)?.month else { return nil }
        return fieldToCaptured.first {
            !consumed.contains($0) && Card.card(id: $0)?.month == month
        }
    }

    /// Unpaired same-month field cards beyond what later movers of that month will pair with.
    private func unclaimedExtras(sameMonthAs mover: Int) -> [Int] {
        guard let month = Card.card(id: mover)?.month else { return [] }
        let sameMonth = { (id: Int) in Card.card(id: id)?.month == month }
        let fieldSet = Set(fieldToCaptured)
        let laterMovers = newlyCaptured.filter {
            $0 != mover && sameMonth($0) && !fieldSet.contains($0) && steps[$0] == nil
        }
        let unpaired = fieldToCaptured.filter { sameMonth($0) && !consumed.contains($0) }
        return Array(unpaired.dropFirst(laterMovers.count))
    }

    /// Plans one moving card.
    /// - Parameter mateAvailable: Whether a mate candidate is drawn on the board and can be met.
    public mutating func plan(_ mover: Int, mateAvailable: (Int) -> Bool) {
        if let mate = partner(of: mover), mateAvailable(mate) {
            steps[mover] = .meet(mate: mate, at: clock)
            landings[mate] = clock + Self.meetDuration
            // A triple match takes every field card of the month with one mover. Field cards
            // not left for a later mover of the same month travel with this pair.
            for extra in unclaimedExtras(sameMonthAs: mover) where mateAvailable(extra) {
                landings[extra] = clock + Self.meetDuration
            }
            clock += Self.captureStepDuration
        } else {
            steps[mover] = .direct(at: clock)
            clock += Self.directStepDuration
        }
    }
}
