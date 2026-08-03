# QuietOverlay

A whole-screen macOS overlay window that **clicks fall straight through** — except where you say they
should not — and that **can never take keyboard focus**.

This is the shell underneath the desk toys I ship: a transparent window covering the desktop, drawing
something small on top of everything, while your editor, your browser and your Dock behave exactly as if
it were not running.

```swift
let ball = BallView()
let overlay = QuietOverlay(content: ball)
overlay.mouseRegion = { point in ball.hitsBall(at: point) }
overlay.show()
```

That is the whole API surface for the common case. Everywhere outside `mouseRegion` the click lands in
whatever is underneath; inside it, your view gets a normal `mouseDown` — and the app the user was typing
in *keeps the caret either way*.

Requires macOS 13+. No dependencies.

## Install

Swift Package Manager:

```swift
.package(url: "https://github.com/safabulat/quiet-overlay", from: "1.0.0")
```

…and add `"QuietOverlay"` to your target's dependencies. In Xcode: **File → Add Package Dependencies**,
paste the same URL.

## Try it

```
swift run QuietOverlayDemo
```

A blue ball appears on your desktop. Drag it around; click anywhere else and the click goes to whatever
is behind it. Quit from the `●` in the menu bar.

## The two things that are easy to get wrong

Both are handled for you. They are written down because they cost me an evening each.

**A window that covers the screen will steal your focus.** Setting `ignoresMouseEvents` is not enough —
the moment your content *does* accept a click, an ordinary `NSWindow` becomes key and the caret leaves
the editor the user was typing in. The fix is a window that structurally cannot become key or main, plus
`orderFrontRegardless()` instead of `makeKeyAndOrderFront(_:)`.

**One event monitor is not enough.** A global monitor sees the cursor while another app is in front, and
stops seeing it the instant the overlay takes the mouse — because the events are no longer "global". With
only that monitor, the region can be entered and never left. `QuietOverlay` runs a global *and* a local
monitor, which is what makes the hand-off symmetrical.

There is a third one the library cannot handle for you: **if your content moves on its own** — an
animation, a physics step — call `refreshMouseOwnership()` from your frame callback. Mouse-moved events
say where the cursor is, not where your ball has drifted to under a cursor that is holding still.

## API

| | |
|---|---|
| `init(content:placement:alwaysOnTop:)` | `content` fills the overlay and is resized with it. `placement` is `.visibleFrame` (everything but the menu bar and Dock, the default) or `.wholeScreen`. |
| `mouseRegion: (CGPoint) -> Bool` | Return `true` where the overlay should receive the mouse. The point arrives in `content`'s own coordinate space, so **flipped views get flipped coordinates** and you never convert by hand. Defaults to claiming nothing. |
| `show()` / `hide()` / `toggle()` | `show()` orders the window in without activating your app. |
| `refreshMouseOwnership()` | Re-decide ownership now. Called for you on every mouse move. |
| `onScreenChange: ((NSRect) -> Void)?` | Fired after the display arrangement changes and the overlay has resized. Re-derive cached geometry here. |
| `alwaysOnTop: Bool` | Float above ordinary windows, or drop back into the normal stacking order. |
| `screen: NSScreen?` | Which screen to cover. `nil` means whichever is currently `NSScreen.main`. |
| `window: OverlayWindow` | The window itself, when you need to reach past all of this. |

`OverlayWindow` is public and usable on its own if you would rather drive the thing yourself — it is a
borderless, transparent, shadowless window that cannot become key or main, joins all Spaces and sits
beside full-screen apps rather than covering them.

## What it deliberately does not do

- **No accessibility permissions.** Nothing here reads other apps' windows, so there is no bouncing off
  the edges of your real windows — that would mean asking for access a small toy has no business asking
  for.
- **No timers.** Mouse ownership is decided from events. A toy that is open all day should not be waking
  the CPU to ask where the cursor is.
- **No keyboard.** A window that cannot become key cannot receive key events, and that is the point. If
  you need shortcuts, register them at the app level.

## Notes

- One overlay covers one screen. For several, make several.
- `acceptsFirstMouse(for:)` should return `true` in your content view, or the first click after another
  app has focus is swallowed as an activating click.

## License

MIT — see [LICENSE](LICENSE).

---

Built for [Deskick](https://safabulat.github.io/deskick-site/) and
[Deskestra](https://safabulat.github.io/deskestra-site/), and extracted so it can be used for something
else. More at [safabulat.github.io](https://safabulat.github.io/).
