import AppKit

/// A whole-screen overlay that clicks fall straight through, except where you say they should not.
///
/// The overlay covers a screen, draws whatever view you hand it, and stays out of the way: it never
/// takes keyboard focus, it never raises itself over a full-screen app, and outside the region you
/// nominate it is completely transparent to the mouse — your editor, your browser and your Dock behave
/// exactly as if it were not running.
///
///     let ball = BallView()
///     let overlay = QuietOverlay(content: ball)
///     overlay.mouseRegion = { point in ball.hitsBall(at: point) }
///     overlay.show()
///
/// Ownership of the mouse is decided *before* any click happens, from mouse-moved events rather than a
/// polling timer — a toy that is open all day should not be waking the CPU to ask where the cursor is.
/// If your content moves on its own (an animation, a physics step), call ``refreshMouseOwnership()``
/// from your frame callback as well, so the region keeps up with the thing that is moving.
public final class QuietOverlay {

    /// How much of the screen the overlay covers.
    public enum Placement {
        /// Everything except the menu bar and the Dock. Nothing you draw can end up somewhere the user
        /// cannot see or reach.
        case visibleFrame
        /// The entire screen, menu bar and Dock included.
        case wholeScreen
    }

    /// The window being driven. Exposed so you can reach past this class when you need to.
    public let window: OverlayWindow

    /// The view filling the overlay.
    public let content: NSView

    /// Return `true` for points where the overlay should receive the mouse, `false` to let the click
    /// through to whatever is underneath.
    ///
    /// The point arrives in `content`'s own coordinate space, so a flipped view gets flipped
    /// coordinates and you never have to do the conversion yourself. Defaults to letting everything
    /// through, which makes a brand-new overlay purely decorative until you say otherwise.
    public var mouseRegion: (CGPoint) -> Bool {
        didSet { refreshMouseOwnership() }
    }

    /// Called after the display arrangement changes and the overlay has resized itself, with the new
    /// frame. Re-derive any geometry you cached from the old size here.
    public var onScreenChange: ((NSRect) -> Void)?

    /// Which screen to cover. `nil` means whichever screen is currently `NSScreen.main`.
    public var screen: NSScreen? {
        didSet { applyFrame() }
    }

    /// Whether the overlay floats above ordinary windows. Turn it off and it behaves like a normal
    /// window in the stacking order, which is what you want for a "stay out of my way for a while" menu
    /// item that is short of hiding it outright.
    public var alwaysOnTop: Bool {
        get { window.level == .floating }
        set { window.level = newValue ? .floating : .normal }
    }

    public var isVisible: Bool { window.isVisible }

    private let placement: Placement
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var screenObserver: NSObjectProtocol?

    // MARK: - Life cycle

    /// - Parameters:
    ///   - content: the view to fill the overlay with. It is resized with the window, so lay out
    ///     against its own bounds rather than a fixed size.
    ///   - placement: how much of the screen to cover. Defaults to everything but the menu bar and Dock.
    ///   - alwaysOnTop: whether to float above ordinary windows. Defaults to `true`.
    public init(content: NSView, placement: Placement = .visibleFrame, alwaysOnTop: Bool = true) {
        self.content = content
        self.placement = placement
        self.mouseRegion = { _ in false }

        let frame = Self.frame(for: placement, on: nil)
        window = OverlayWindow(frame: frame)
        content.frame = NSRect(origin: .zero, size: frame.size)
        content.autoresizingMask = [.width, .height]
        window.contentView = content
        window.level = alwaysOnTop ? .floating : .normal

        // Both monitors are needed and they do not overlap: the global one sees the cursor while another
        // app is in front, the local one sees it while the overlay itself owns the mouse. With only the
        // global monitor the region can never be released once entered, because the moment the overlay
        // takes the mouse its own events stop being "global".
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) {
            [weak self] _ in self?.refreshMouseOwnership()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) {
            [weak self] event in
            self?.refreshMouseOwnership()
            return event
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.applyFrame()
        }
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    // MARK: - Showing

    /// Puts the overlay on screen without activating the app or disturbing the front window.
    public func show() {
        // Never `makeKeyAndOrderFront`: that would pull focus out of whatever the user is typing in,
        // which is the one thing this window exists not to do.
        window.orderFrontRegardless()
        refreshMouseOwnership()
    }

    public func hide() {
        window.orderOut(nil)
        window.ignoresMouseEvents = true
    }

    public func toggle() {
        isVisible ? hide() : show()
    }

    // MARK: - Mouse ownership

    /// Re-decides whether the overlay should be listening to the mouse right now.
    ///
    /// Called for you on every mouse move. Call it yourself as well whenever the content moves under a
    /// stationary cursor — otherwise the region is a frame behind the thing it is describing.
    public func refreshMouseOwnership() {
        guard window.isVisible else {
            window.ignoresMouseEvents = true
            return
        }
        let mouse = NSEvent.mouseLocation                   // screen coordinates, y up
        guard window.frame.contains(mouse) else {
            window.ignoresMouseEvents = true
            return
        }
        // Straight through AppKit's own conversion rather than arithmetic on the frame: it is the part
        // that knows whether `content` is flipped, and getting it wrong mirrors the region vertically.
        let inWindow = window.convertPoint(fromScreen: mouse)
        let inContent = content.convert(inWindow, from: nil)

        let wants = mouseRegion(inContent)
        if window.ignoresMouseEvents == wants { window.ignoresMouseEvents = !wants }
    }

    // MARK: - Geometry

    private func applyFrame() {
        let frame = Self.frame(for: placement, on: screen)
        guard frame != window.frame else { return }
        window.setFrame(frame, display: true)
        content.frame = NSRect(origin: .zero, size: frame.size)
        onScreenChange?(frame)
        refreshMouseOwnership()
    }

    private static func frame(for placement: Placement, on screen: NSScreen?) -> NSRect {
        let target = screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let target else { return NSRect(x: 0, y: 0, width: 1, height: 1) }
        switch placement {
        case .visibleFrame: return target.visibleFrame
        case .wholeScreen:  return target.frame
        }
    }
}
