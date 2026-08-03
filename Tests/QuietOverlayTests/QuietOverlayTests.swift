import AppKit
import XCTest
@testable import QuietOverlay

final class OverlayWindowTests: XCTestCase {

    func testWindowCannotTakeFocus() {
        let window = OverlayWindow(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        // The whole reason this type exists. If either of these ever returns true, clicking the overlay
        // pulls the caret out of whatever the user was typing in.
        XCTAssertFalse(window.canBecomeKey)
        XCTAssertFalse(window.canBecomeMain)
    }

    func testWindowStartsTransparentToTheMouse() {
        let window = OverlayWindow(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(window.ignoresMouseEvents, "a fresh overlay must not steal clicks before it is asked to")
        XCTAssertFalse(window.isOpaque)
        XCTAssertFalse(window.hasShadow)
        XCTAssertEqual(window.backgroundColor, .clear)
    }

    func testWindowFollowsTheUserBetweenSpaces() {
        let window = OverlayWindow(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertTrue(window.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(window.collectionBehavior.contains(.stationary))
    }
}

final class QuietOverlayTests: XCTestCase {

    func testContentIsInstalledAndResizes() {
        let content = NSView()
        let overlay = QuietOverlay(content: content)
        XCTAssertIdentical(overlay.window.contentView, content)
        XCTAssertEqual(content.autoresizingMask, [.width, .height])
        XCTAssertEqual(content.frame.size, overlay.window.frame.size)
    }

    func testDefaultRegionClaimsNothing() {
        let overlay = QuietOverlay(content: NSView())
        // A brand-new overlay is purely decorative until a region is nominated, so an app that forgets
        // to set one is harmless rather than a screen-sized click trap.
        XCTAssertFalse(overlay.mouseRegion(CGPoint(x: 10, y: 10)))
        XCTAssertTrue(overlay.window.ignoresMouseEvents)
    }

    func testAlwaysOnTopMapsToWindowLevel() {
        let overlay = QuietOverlay(content: NSView(), alwaysOnTop: true)
        XCTAssertEqual(overlay.window.level, .floating)
        XCTAssertTrue(overlay.alwaysOnTop)

        overlay.alwaysOnTop = false
        XCTAssertEqual(overlay.window.level, .normal)
        XCTAssertFalse(overlay.alwaysOnTop)
    }

    func testStartsOffScreenLevelWhenAskedTo() {
        let overlay = QuietOverlay(content: NSView(), alwaysOnTop: false)
        XCTAssertEqual(overlay.window.level, .normal)
    }

    func testHiddenOverlayNeverOwnsTheMouse() {
        let overlay = QuietOverlay(content: NSView())
        overlay.mouseRegion = { _ in true }     // claims everything...
        overlay.hide()
        overlay.refreshMouseOwnership()
        XCTAssertTrue(overlay.window.ignoresMouseEvents, "...but not while it is off screen")
    }

    func testVisibleFramePlacementExcludesTheMenuBar() throws {
        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
        let overlay = QuietOverlay(content: NSView(), placement: .visibleFrame)
        XCTAssertEqual(overlay.window.frame, screen.visibleFrame)
        XCTAssertLessThan(overlay.window.frame.height, screen.frame.height,
                          "visibleFrame should be shorter than the screen — the menu bar lives in the difference")
    }

    func testWholeScreenPlacementCoversEverything() throws {
        let screen = try XCTUnwrap(NSScreen.main ?? NSScreen.screens.first)
        let overlay = QuietOverlay(content: NSView(), placement: .wholeScreen)
        XCTAssertEqual(overlay.window.frame, screen.frame)
    }
}
