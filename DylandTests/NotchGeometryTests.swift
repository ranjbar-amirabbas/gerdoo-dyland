import XCTest
@testable import Dyland

final class NotchGeometryTests: XCTestCase {

    private let builtInNotched = ScreenDescriptor(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        safeAreaTopInset: 37,
        auxiliaryTopLeftWidth: 656,
        auxiliaryTopRightWidth: 656,
        isBuiltIn: true
    )

    private let externalDisplay = ScreenDescriptor(
        frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
        safeAreaTopInset: 0,
        auxiliaryTopLeftWidth: 0,
        auxiliaryTopRightWidth: 0,
        isBuiltIn: false
    )

    func testNotchedDisplayMeasuresTheCutout() {
        let g = NotchGeometryProvider.resolve(screen: builtInNotched)
        XCTAssertTrue(g.hasPhysicalNotch)
        XCTAssertEqual(g.notchSize.width, 200, accuracy: 0.001)
        XCTAssertEqual(g.notchSize.height, 37, accuracy: 0.001)
        XCTAssertEqual(g.topCornerRadius, 0, "A real notch must stay square at the bezel")
    }

    func testExternalDisplayFallsBackToASyntheticPill() {
        let metrics = NotchMetrics()
        let g = NotchGeometryProvider.resolve(screen: externalDisplay, metrics: metrics)
        XCTAssertFalse(g.hasPhysicalNotch)
        XCTAssertEqual(g.notchSize, metrics.syntheticNotchSize)
        XCTAssertGreaterThan(g.topCornerRadius, 0, "Without a bezel cutout the pill needs rounding")
    }

    func testInsetWithoutAuxiliaryAreasIsNotTreatedAsANotch() {
        var descriptor = externalDisplay
        descriptor.safeAreaTopInset = 24
        XCTAssertFalse(descriptor.hasPhysicalNotch)
    }

    func testCollapsedWidthNeverDropsBelowTheMinimum() {
        var narrow = builtInNotched
        narrow.auxiliaryTopLeftWidth = 740
        narrow.auxiliaryTopRightWidth = 740
        let g = NotchGeometryProvider.resolve(screen: narrow)
        XCTAssertEqual(g.collapsedSize.width, NotchMetrics().minimumCollapsedWidth)
    }

    func testPanelIsClampedToSmallScreens() {
        let tiny = ScreenDescriptor(
            frame: CGRect(x: 0, y: 0, width: 400, height: 300),
            safeAreaTopInset: 0,
            auxiliaryTopLeftWidth: 0,
            auxiliaryTopRightWidth: 0,
            isBuiltIn: false
        )
        let g = NotchGeometryProvider.resolve(screen: tiny)
        XCTAssertLessThanOrEqual(g.windowSize.width, tiny.frame.width)
        XCTAssertLessThanOrEqual(g.expandedSize.height, tiny.frame.height * 0.4)
    }

    func testWindowIsPinnedToTheTopCentreOfItsScreen() {
        let g = NotchGeometryProvider.resolve(screen: externalDisplay)
        XCTAssertEqual(g.windowFrame.midX, externalDisplay.frame.midX, accuracy: 0.001)
        XCTAssertEqual(g.windowFrame.maxY, externalDisplay.frame.maxY, accuracy: 0.001)
    }

    func testInteractiveRectGrowsWhenOpen() {
        let g = NotchGeometryProvider.resolve(screen: builtInNotched)
        let collapsed = g.interactiveRect(for: .collapsed)
        let expanded = g.interactiveRect(for: .open)
        XCTAssertGreaterThan(expanded.width, collapsed.width)
        XCTAssertGreaterThan(expanded.height, collapsed.height)
        XCTAssertEqual(collapsed.midX, expanded.midX, accuracy: 0.001)
    }

    func testPeekSitsBetweenCollapsedAndOpen() {
        let g = NotchGeometryProvider.resolve(screen: builtInNotched)
        XCTAssertGreaterThan(g.peekSize.width, g.collapsedSize.width)
        XCTAssertLessThan(g.peekSize.width, g.expandedSize.width)
        XCTAssertEqual(g.peekSize.height, g.collapsedSize.height, "A peek widens; it must not grow downward")
    }

    func testDragCatchZoneIsMoreForgivingThanTheCollapsedPill() {
        let g = NotchGeometryProvider.resolve(screen: builtInNotched)
        XCTAssertGreaterThan(g.dragCatchZone.width, g.collapsedSize.width)
        XCTAssertGreaterThan(g.dragCatchZone.height, g.collapsedSize.height)
    }
}

final class NotchPresentationResolverTests: XCTestCase {

    private func resolve(_ state: NotchState, hasMedia: Bool = false, waveform: Bool = true) -> NotchPresentation {
        NotchPresentationResolver.resolve(state: state, hasMedia: hasMedia, waveformEnabled: waveform)
    }

    func testOpenStatesAlwaysUseTheFullPanel() {
        XCTAssertEqual(resolve(.expanded(.nowPlaying)), .open)
        XCTAssertEqual(resolve(.dragTarget), .open)
    }

    func testCollapsedStaysNarrowWithoutMedia() {
        XCTAssertEqual(resolve(.collapsed), .collapsed)
        XCTAssertEqual(resolve(.hovered), .collapsed)
    }

    func testCollapsedWidensWhenMediaIsLoaded() {
        XCTAssertEqual(resolve(.collapsed, hasMedia: true), .peek)
        XCTAssertEqual(resolve(.hovered, hasMedia: true), .peek)
    }

    func testWaveformPreferenceSuppressesTheIdlePeek() {
        XCTAssertEqual(resolve(.collapsed, hasMedia: true, waveform: false), .collapsed)
    }

    func testExplicitPeekIgnoresTheWaveformPreference() {
        XCTAssertEqual(resolve(.mediaPreview, hasMedia: true, waveform: false), .peek)
        XCTAssertEqual(resolve(.mediaPreview, hasMedia: false, waveform: false), .peek)
    }
}

final class WaveformLevelTests: XCTestCase {

    func testProceduralLevelsStayInRange() {
        let provider = ProceduralLevelProvider()
        for step in 0..<200 {
            let levels = provider.levels(count: 7, at: Double(step) * 0.033)
            XCTAssertEqual(levels.count, 7)
            for level in levels {
                XCTAssertGreaterThanOrEqual(level, provider.floorLevel - 0.0001)
                XCTAssertLessThanOrEqual(level, 1.0001)
            }
        }
    }

    func testProceduralLevelsAreAFunctionOfTimeAlone() {
        let provider = ProceduralLevelProvider()
        XCTAssertEqual(provider.levels(count: 5, at: 12.5), provider.levels(count: 5, at: 12.5))
    }

    func testNeighbouringBarsDoNotMoveInLockstep() {
        let levels = ProceduralLevelProvider().levels(count: 5, at: 3.0)
        XCTAssertNotEqual(levels[0], levels[1], accuracy: 0.0001)
    }

    func testZeroBarsIsHandled() {
        XCTAssertTrue(ProceduralLevelProvider().levels(count: 0, at: 1).isEmpty)
    }
}
