import AppKit
import QuietOverlay

/// A ball you can drag around your desktop, and nothing else.
///
/// The point of the demo is what it *does not* do: everywhere except the ball, your clicks land in
/// whatever is underneath, and dragging the ball never takes focus away from the app you were typing
/// in. Deliberately a flipped view, so the coordinate handling gets exercised rather than assumed.
final class BallView: NSView {

    override var isFlipped: Bool { true }

    private let radius: CGFloat = 46
    private var center = CGPoint(x: 260, y: 260)
    private var grabOffset = CGSize.zero

    /// Called after the ball moves, so the overlay can re-decide whether it still owns the mouse.
    var onMove: (() -> Void)?

    func hitsBall(at point: CGPoint) -> Bool {
        hypot(point.x - center.x, point.y - center.y) <= radius
    }

    override func draw(_ dirtyRect: NSRect) {
        let box = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let ball = NSBezierPath(ovalIn: box)

        NSGraphicsContext.current?.saveGraphicsState()
        NSShadow.dropped(radius: 18, opacity: 0.45).set()
        NSColor(calibratedRed: 0.29, green: 0.62, blue: 0.94, alpha: 1).setFill()
        ball.fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        NSColor(white: 1, alpha: 0.85).setStroke()
        ball.lineWidth = 2
        ball.stroke()

        let label = "drag me" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor(white: 1, alpha: 0.9)
        ]
        let size = label.size(withAttributes: attrs)
        label.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), withAttributes: attrs)
    }

    // Without this the first click after another app has focus is swallowed as an activating click, and
    // the ball only starts moving on the second grab.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        grabOffset = CGSize(width: center.x - p.x, height: center.y - p.y)
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        center = CGPoint(
            x: min(max(p.x + grabOffset.width, radius), bounds.width - radius),
            y: min(max(p.y + grabOffset.height, radius), bounds.height - radius)
        )
        needsDisplay = true
        onMove?()
    }

    func bringInsideBounds() {
        center = CGPoint(
            x: min(max(center.x, radius), bounds.width - radius),
            y: min(max(center.y, radius), bounds.height - radius)
        )
        needsDisplay = true
    }
}

private extension NSShadow {
    static func dropped(radius: CGFloat, opacity: CGFloat) -> NSShadow {
        let s = NSShadow()
        s.shadowBlurRadius = radius
        s.shadowOffset = NSSize(width: 0, height: -3)
        s.shadowColor = NSColor(white: 0, alpha: opacity)
        return s
    }
}

final class Demo: NSObject, NSApplicationDelegate {

    private var overlay: QuietOverlay!
    private var ball: BallView!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        ball = BallView()
        overlay = QuietOverlay(content: ball)
        overlay.mouseRegion = { [weak ball] point in ball?.hitsBall(at: point) ?? false }
        // The ball moves under a cursor that is not itself moving, so the overlay has to be told.
        ball.onMove = { [weak overlay] in overlay?.refreshMouseOwnership() }
        overlay.onScreenChange = { [weak ball] _ in ball?.bringInsideBounds() }
        overlay.show()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "●"
        let menu = NSMenu()
        menu.addItem(withTitle: "QuietOverlay demo", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }
}

let app = NSApplication.shared
// No Dock icon and no window in the app switcher — the same policy a real desk toy ships with.
app.setActivationPolicy(.accessory)
let delegate = Demo()
app.delegate = delegate
app.run()
