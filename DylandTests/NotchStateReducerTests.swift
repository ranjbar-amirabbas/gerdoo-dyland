import XCTest
@testable import Dyland

/// The reducer is pure, so these tests need no window, run loop or clock.
final class NotchStateReducerTests: XCTestCase {

    private let config = NotchStateConfig(
        hoverExpansionEnabled: true,
        expansionDelay: 0.2,
        collapseDelay: 0.4,
        previewDuration: 1.0,
        postDropDwell: 3.0,
        attentionDwell: 2.0,
        defaultSection: .nowPlaying
    )

    private func reduce(_ state: NotchState, _ event: NotchEvent, _ config: NotchStateConfig? = nil) -> NotchTransition {
        NotchStateReducer.reduce(state: state, event: event, config: config ?? self.config)
    }

    // MARK: Hover

    func testHoverFromCollapsedSchedulesExpansion() {
        let t = reduce(.collapsed, .hoverBegan)
        XCTAssertEqual(t.state, .hovered)
        XCTAssertEqual(t.scheduled, ScheduledNotchEvent(event: .expansionTimerFired, delay: 0.2))
    }

    func testHoverDoesNotAutoExpandWhenDisabled() {
        var disabled = config
        disabled.hoverExpansionEnabled = false
        let t = reduce(.collapsed, .hoverBegan, disabled)
        XCTAssertEqual(t.state, .hovered)
        XCTAssertNil(t.scheduled, "Hover affordance should show, but nothing should be scheduled")
    }

    func testExpansionTimerOnlyFiresFromHovered() {
        XCTAssertEqual(reduce(.hovered, .expansionTimerFired).state, .expanded(.nowPlaying))
        XCTAssertEqual(reduce(.collapsed, .expansionTimerFired).state, .collapsed)
        XCTAssertEqual(reduce(.dragTarget, .expansionTimerFired).state, .dragTarget)
    }

    func testHoverEndedFromHoveredCollapsesImmediately() {
        let t = reduce(.hovered, .hoverEnded)
        XCTAssertEqual(t.state, .collapsed)
        XCTAssertNil(t.scheduled)
    }

    func testHoverEndedFromExpandedSchedulesCollapse() {
        let t = reduce(.expanded(.fileShelf), .hoverEnded)
        XCTAssertEqual(t.state, .expanded(.fileShelf))
        XCTAssertEqual(t.scheduled, ScheduledNotchEvent(event: .collapseTimerFired, delay: 0.4))
    }

    func testHoverReturningWhileExpandedCancelsPendingCollapse() {
        let t = reduce(.expanded(.nowPlaying), .hoverBegan)
        XCTAssertEqual(t.state, .expanded(.nowPlaying))
        XCTAssertNil(t.scheduled, "A nil schedule cancels the outstanding collapse")
    }

    // MARK: Drag outranks hover

    func testDragTargetIgnoresHoverEvents() {
        XCTAssertEqual(reduce(.dragTarget, .hoverBegan).state, .dragTarget)
        XCTAssertEqual(reduce(.dragTarget, .hoverEnded).state, .dragTarget)
    }

    func testDragEnteredAlwaysWins() {
        for state: NotchState in [.collapsed, .hovered, .expanded(.quickActions), .mediaPreview] {
            XCTAssertEqual(reduce(state, .dragEntered).state, .dragTarget)
        }
    }

    func testDragExitedKeepsTargetButSchedulesCollapse() {
        let t = reduce(.dragTarget, .dragExited)
        XCTAssertEqual(t.state, .dragTarget)
        XCTAssertEqual(t.scheduled, ScheduledNotchEvent(event: .collapseTimerFired, delay: 0.4))
    }

    func testDropOpensShelfAndDwells() {
        let t = reduce(.dragTarget, .dropped)
        XCTAssertEqual(t.state, .expanded(.fileShelf))
        XCTAssertEqual(t.scheduled, ScheduledNotchEvent(event: .collapseTimerFired, delay: 3.0))
    }

    // MARK: Click

    func testClickTogglesExpansion() {
        XCTAssertEqual(reduce(.collapsed, .clicked).state, .expanded(.nowPlaying))
        XCTAssertEqual(reduce(.expanded(.fileShelf), .clicked).state, .collapsed)
    }

    // MARK: Media

    func testMediaChangePreviewsOnlyWhileCollapsed() {
        let preview = reduce(.collapsed, .mediaChanged)
        XCTAssertEqual(preview.state, .mediaPreview)
        XCTAssertEqual(preview.scheduled, ScheduledNotchEvent(event: .previewTimerFired, delay: 1.0))

        XCTAssertEqual(reduce(.expanded(.fileShelf), .mediaChanged).state, .expanded(.fileShelf),
                       "A track change must not yank the user out of another section")
        XCTAssertEqual(reduce(.dragTarget, .mediaChanged).state, .dragTarget)
    }

    func testPreviewTimerReturnsToCollapsed() {
        XCTAssertEqual(reduce(.mediaPreview, .previewTimerFired).state, .collapsed)
        XCTAssertEqual(reduce(.expanded(.nowPlaying), .previewTimerFired).state, .expanded(.nowPlaying))
    }

    // MARK: Attention, selection, dismissal

    func testAttentionOpensSectionAndDwells() {
        let t = reduce(.collapsed, .attentionRequested(.quickActions))
        XCTAssertEqual(t.state, .expanded(.quickActions))
        XCTAssertEqual(t.scheduled, ScheduledNotchEvent(event: .collapseTimerFired, delay: 2.0))
    }

    func testAttentionNeverInterruptsADrag() {
        XCTAssertEqual(reduce(.dragTarget, .attentionRequested(.nowPlaying)).state, .dragTarget)
    }

    func testSelectSectionSwitchesWithoutTimer() {
        let t = reduce(.expanded(.nowPlaying), .selectSection(.fileShelf))
        XCTAssertEqual(t.state, .expanded(.fileShelf))
        XCTAssertNil(t.scheduled)
    }

    func testDismissAlwaysCollapses() {
        for state: NotchState in [.hovered, .expanded(.nowPlaying), .dragTarget, .mediaPreview] {
            XCTAssertEqual(reduce(state, .dismiss).state, .collapsed)
        }
    }

    func testCollapseTimerIgnoredWhenNotOpen() {
        XCTAssertEqual(reduce(.hovered, .collapseTimerFired).state, .hovered)
        XCTAssertEqual(reduce(.mediaPreview, .collapseTimerFired).state, .mediaPreview)
    }
}

@MainActor
final class NotchStateMachineTests: XCTestCase {

    func testMachineRemembersTheLastSelectedSection() {
        let machine = NotchStateMachine(config: NotchStateConfig(defaultSection: .nowPlaying))

        machine.send(.selectSection(.fileShelf))
        machine.send(.dismiss)
        machine.send(.clicked)

        XCTAssertEqual(machine.state, .expanded(.fileShelf),
                       "Reopening must return to what the user was last looking at")
    }

    func testDropMakesTheShelfTheRememberedSection() {
        let machine = NotchStateMachine(config: NotchStateConfig(defaultSection: .nowPlaying))

        machine.send(.dropped)
        machine.send(.dismiss)
        machine.send(.clicked)

        XCTAssertEqual(machine.state, .expanded(.fileShelf))
    }

    func testApplyingSettingsPreservesAStillAvailableSection() {
        let machine = NotchStateMachine(config: NotchStateConfig(defaultSection: .nowPlaying))
        machine.send(.selectSection(.clipboard))

        machine.apply(
            config: NotchStateConfig(collapseDelay: 2.0, defaultSection: .nowPlaying),
            availableSections: [.nowPlaying, .clipboard]
        )

        XCTAssertEqual(machine.config.defaultSection, .clipboard)
        XCTAssertEqual(machine.config.collapseDelay, 2.0, accuracy: 0.0001)
    }

    func testApplyingSettingsDropsASectionTheUserDisabled() {
        let machine = NotchStateMachine(config: NotchStateConfig(defaultSection: .nowPlaying))
        machine.send(.selectSection(.clipboard))

        machine.apply(
            config: NotchStateConfig(defaultSection: .fileShelf),
            availableSections: [.nowPlaying, .fileShelf]
        )

        XCTAssertEqual(machine.config.defaultSection, .fileShelf)
    }

    func testTransitionCancelsThePendingTimer() async {
        let machine = NotchStateMachine(config: NotchStateConfig(expansionDelay: 10))
        machine.send(.hoverBegan)
        XCTAssertTrue(machine.hasPendingTimer)

        machine.send(.dismiss)

        XCTAssertFalse(machine.hasPendingTimer)
        XCTAssertEqual(machine.state, .collapsed)
    }

    func testExpansionTimerActuallyFires() async throws {
        let machine = NotchStateMachine(config: NotchStateConfig(expansionDelay: 0.05))
        machine.send(.hoverBegan)
        XCTAssertEqual(machine.state, .hovered)

        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(machine.state, .expanded(.nowPlaying))
    }

    func testResetClearsEverything() {
        let machine = NotchStateMachine(config: NotchStateConfig(collapseDelay: 10))
        machine.send(.clicked)
        machine.send(.hoverEnded)

        machine.reset()

        XCTAssertEqual(machine.state, .collapsed)
        XCTAssertFalse(machine.hasPendingTimer)
    }
}
