import Testing

@testable import KoikoiUI

/// Pairing of moving cards with captured field cards on the visionOS spatial board
/// (`SpatialCapturePlanner`). A captured field card left without a plan stays on the field.
@Suite struct SpatialCapturePlannerTests {
    // The four September (chrysanthemum) cards
    private let sakeCup = 32
    private let blueRibbon = 33
    private let chaff1 = 34
    private let chaff2 = 35
    // January (pine)
    private let crane = 0
    private let pineChaff = 2

    /// Single match: the mover meets its mate, and the mate heads to the captured panel.
    @Test func singleMatchMeetsItsMate() {
        var planner = SpatialCapturePlanner(
            newlyCaptured: [sakeCup, blueRibbon], fieldToCaptured: [blueRibbon])
        planner.plan(sakeCup) { _ in true }

        #expect(planner.steps[sakeCup] == .meet(mate: blueRibbon, at: 0))
        #expect(planner.landings[blueRibbon] == SpatialCapturePlanner.meetDuration)
    }

    /// Three of a month on the field taken by the fourth: all three head to the captured panel.
    @Test func tripleMatchSendsEveryFieldCardToThePanel() {
        let field = [blueRibbon, chaff1, chaff2]
        var planner = SpatialCapturePlanner(
            newlyCaptured: Set(field + [sakeCup]), fieldToCaptured: field)
        planner.plan(sakeCup) { _ in true }

        #expect(Set(planner.landings.keys) == Set(field))
    }

    /// Hand card and drawn card of the same month each take one: each pairs with its own mate.
    @Test func twoMoversOfTheSameMonthTakeOneMateEach() {
        var planner = SpatialCapturePlanner(
            newlyCaptured: [sakeCup, blueRibbon, chaff1, chaff2],
            fieldToCaptured: [blueRibbon, chaff1])
        planner.plan(sakeCup) { _ in true }
        planner.plan(chaff2) { _ in true }

        #expect(planner.steps[sakeCup] == .meet(mate: blueRibbon, at: 0))
        #expect(
            planner.steps[chaff2]
                == .meet(mate: chaff1, at: SpatialCapturePlanner.captureStepDuration))
        #expect(Set(planner.landings.keys) == [blueRibbon, chaff1])
    }

    /// A card merely laid on the field (not captured) has no mate.
    @Test func cardLaidOnTheFieldGoesDirect() {
        var planner = SpatialCapturePlanner(newlyCaptured: [], fieldToCaptured: [])
        planner.plan(crane) { _ in true }

        #expect(planner.steps[crane] == .direct(at: 0))
        #expect(planner.landings.isEmpty)
    }

    /// Cards of a different month are never paired.
    @Test func mateMustShareTheMonth() {
        let planner = SpatialCapturePlanner(
            newlyCaptured: [sakeCup, pineChaff], fieldToCaptured: [pineChaff])

        #expect(planner.partner(of: sakeCup) == nil)
    }
}
