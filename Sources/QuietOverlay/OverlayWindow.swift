import AppKit

/// A borderless, transparent window that can never become key or main.
///
/// This is the whole trick behind a desk toy that is allowed to sit on top of everything: a window that
/// takes focus away from the editor you were typing in has stopped being a toy and become an
/// interruption. Overriding the two properties means AppKit will not hand it focus even if something
/// asks — there is no code path left that can steal the caret.
///
/// Use it directly if you want to own the setup yourself; ``QuietOverlay`` builds and drives one for you.
open class OverlayWindow: NSWindow {

    open override var canBecomeKey: Bool { false }
    open override var canBecomeMain: Bool { false }

    /// Builds a transparent, shadowless, borderless window sized to `frame`.
    public convenience init(frame: NSRect) {
        self.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // Follows the user between Spaces and sits quietly beside full-screen apps rather than covering
        // them; `.stationary` keeps it from sliding around during a Mission Control swipe.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        // The screen belongs to the user until the content earns a piece of it.
        ignoresMouseEvents = true
    }
}
