# gerdoo-dyland

A macOS menu-bar utility that turns the MacBook notch into an interactive control centre: Now Playing, a drag-and-drop File Shelf, clipboard history, and Quick Actions. It collapses into the camera housing when idle and expands on hover, click, drag, or a track change.

Built from scratch with public Apple APIs only. Swift, SwiftUI, and AppKit where SwiftUI cannot reach.

- **Requires** macOS 14 or later. Built with Xcode 16+.
- **Product name is `gerdoo-dyland`**; the Swift module and source folder stay `Dyland`, because a module name has to be a valid Swift identifier. `PRODUCT_MODULE_NAME` pins this in the project file.
- **Works with and without a physical notch** — displays with no camera housing get a synthetic centred pill.

```bash
xcodebuild -project gerdoo-dyland.xcodeproj -scheme gerdoo-dyland -configuration Debug build
```

```bash
xcodebuild -project gerdoo-dyland.xcodeproj -scheme gerdoo-dyland test
```

## What it does

| Module | Behaviour |
|---|---|
| **Notch window** | Borderless, transparent, non-activating `NSPanel` above the menu bar. No Dock icon, no Cmd+Tab entry. Follows display changes, sleep/wake, and Space switches. |
| **Now Playing** | Artwork, title, artist/album, transport controls, and an extrapolated progress bar for Music and Spotify. |
| **Waveform** | Core Animation equaliser bars beside the notch while media plays. Stops on pause; costs the app nothing per frame. |
| **File Shelf** | Drag files at the notch to park them. Drag them back out into Finder, Mail, a browser, an IDE. References only — nothing is ever copied or moved. |
| **Clipboard** | Last 10 copied text snippets or file URLs, in memory. Click one to put it back on the pasteboard. |
| **Quick Actions** | Screenshot, Clipboard, Downloads, Desktop, Empty Shelf, Finder. Pluggable — one file plus one registration line adds another. |
| **Settings** | General (login item, hover expansion, delays), Modules (four on/off switches), Appearance (size, animation intensity, waveform). |

## Architecture

```
Dyland/                 # Swift module sources
  App/            Lifecycle and the object graph (AppEnvironment)
  Core/           NotchState, the reducer and state machine, design tokens, logging
  Notch/          Panel, host view, geometry, screen observer, and the notch views
  Media/          MediaProvider protocol, MediaManager, providers, Now Playing UI, waveform
  FileShelf/      FileShelfManager, DragDropManager, shelf UI
  QuickActions/   QuickAction protocol, manager, actions, grid UI
  System/         Clipboard monitoring, login item, menu-bar item
  Settings/       Store, manager, settings panes
  Models/         Shared value types
  Services/       AppleScript runner, icon cache, module coordinator
  Utilities/      NSScreen bridging, NSVisualEffectView bridging
```

Three rules hold the design together.

**One state machine.** `NotchState` is a single enum (`collapsed`, `hovered`, `expanded(section)`, `dragTarget`, `mediaPreview`) and every transition goes through `NotchStateReducer` — a pure, synchronous function of `(state, event, config)`. `NotchStateMachine` only applies transitions and owns *one* cancellable timer, so a stale timer can never race a fresh state. There are no scattered booleans and no `if isHovering && !isDragging` anywhere in the UI.

Size is derived separately, by `NotchPresentationResolver` (`collapsed` / `peek` / `open`), because two different states can share a size — a collapsed notch with music loaded is as wide as an explicit media peek. That keeps the state machine ignorant of media.

**Protocols at every integration boundary.** `MediaProvider`, `QuickAction`, and `AudioLevelProvider` are the seams. Nothing in the UI layer knows that Spotify or Music exist, and `MockMediaProvider` drives the entire Now Playing interface with no player installed.

**One object graph, no singletons.** `AppEnvironment` is constructed once in `AppDelegate` and injected downward. Every manager is an `@MainActor final class … : ObservableObject` that exposes read-only `@Published` state plus intent methods.

AppKit is confined to `Notch/`, `System/MenuBarController`, `Services/AppleScriptRunner`, `Media/Waveform/WaveformBarsView`, and two small `NSViewRepresentable` bridges. SwiftUI views never touch an `NSWindow`.

### Two AppKit behaviours worth knowing

`NotchHostView` carries the only genuinely unusual code in the project, and both overrides are load-bearing:

1. **Selective hit testing.** The panel is always the size of the fully expanded UI. Without an override, that transparent rectangle would swallow every click in the top centre of the screen. `hitTest(_:)` returns `nil` outside the region the notch currently occupies, so everything else falls through to the app underneath.
2. **A drag catch zone.** macOS has no public way to observe a drag *before* it reaches one of your windows. The panel therefore registers a catch zone that is deliberately wider and taller than the collapsed pill, and expands the moment a drag enters it. Drags that never come near the notch are invisible to the app, by design.

## Installing a build

Releases ship an ad-hoc signed, un-notarized DMG, so macOS blocks the first launch with *"Apple could not verify this app is free of malware."*

Drag the app into `/Applications` first — launching it from the mounted disk image fails for a separate reason with an identical-looking dialog — then either clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/gerdoo-dyland.app
```

…or open it once, dismiss the warning, and click **Open Anyway** in **System Settings ▸ Privacy & Security**.

Right-clicking the app and choosing **Open** does *not* work on macOS 15 or later; Apple removed that bypass.

## Permissions

The app asks for as little as possible.

| Permission | When | What breaks without it |
|---|---|---|
| **Automation** (Music / Spotify) | First time you press play/pause/next, or when the playhead is read | Transport controls and the progress bar. Track metadata still works — it arrives over distributed notifications, which need no permission. |
| **Login item** | Only if you turn on "Launch at login" | Nothing else. |

**Not requested:** Accessibility, Screen Recording, Full Disk Access, Camera, Microphone, Contacts, or network access beyond fetching Spotify artwork over HTTPS.

The app is **not sandboxed** (hardened runtime only). Two reasons: the File Shelf holds references to files from anywhere the user drags them, which outside the sandbox stay valid with no security-scoped bookmark bookkeeping; and the media providers speak Apple events. As configured, the app cannot ship on the Mac App Store.

## Limitations

These are real constraints of the public API surface, not shortcuts. Each one is commented at the relevant call site too.

**There is no system-wide Now Playing API.** `MediaRemote` is private *and*, since macOS 15.4, entitlement-gated — unentitled processes get nothing back from it. It therefore integrates per application behind `MediaProvider`, shipping Music and Spotify. Anything else playing audio (a browser tab, VLC, a game) is invisible. Adding a player means adding a conformer.

**Drags are only seen once they reach the catch zone.** No public API reports a drag session in progress elsewhere on screen, so the notch cannot expand while a file is still halfway up the display.

**The clipboard is polled.** `NSPasteboard` posts no change notification of any kind. The app compares `changeCount` once a second with a 0.5 s tolerance so the kernel can coalesce the wakeup, and the timer exists only while the Clipboard module is enabled. Only text and file URLs are captured; images and rich text are out of scope for now.

**The waveform is procedural, not real audio.** Reading another application's audio levels requires a system audio tap and the screen-recording class of permission that comes with it. `AudioLevelProvider` and `WaveformView.levels` are the seam: pass sampled values and the bars follow them instead of self-animating.

**Screenshot opens the system Screenshot app** rather than running `screencapture -i`. A capture the app starts itself is attributed to the app, which would make macOS demand Screen Recording permission for a feature that does not need it.

**The notch stays visible over full-screen apps.** `.fullScreenAuxiliary` is the closest public behaviour. Detecting that another application has gone full screen on a given display is not publicly exposed, and the available heuristic (the menu bar being hidden) also matches the "automatically hide the menu bar" preference, which would break the app for those users.

**The shelf is in memory only.** Files stay until removed, cleared, or the app quits. Persisting them would need security-scoped bookmarks and a stale-reference policy; the shelf is a staging area for a drag you are in the middle of, not a document store.

## Performance

Measured on a MacBook Air (M3, 15-inch), release-equivalent debug build:

| State | CPU | Memory |
|---|---|---|
| Idle, collapsed | **0.0 %** | ~16 MB |
| Music playing, waveform animating in the pill | **0.0 %** | ~16 MB |
| Expanded, Now Playing with a live progress bar | 0.5–0.7 % | ~20 MB |

Nothing polls at idle. Media state is push-driven by `DistributedNotificationCenter`; the playhead is *extrapolated* from the last snapshot rather than queried on a timer; collapse and expansion delays are single cancellable `Task`s; the progress bar's timeline only runs while the panel is open.

The waveform is the one place where this took real work. A four-bar SwiftUI `Canvas` in the collapsed pill cost **5.4 % CPU and 75 MB** while music played, because any per-frame drawing in a large transparent window forces a full recomposite *and* wakes the process 20–120 times a second. Rewriting it as Core Animation layers with repeating `CABasicAnimation`s moved the work into the render server: same animation, 0.0 % process CPU.

## Development

Debug builds honour three environment variables so the UI can be exercised without real data:

```bash
DYLAND_DEBUG_MEDIA=1 ./gerdoo-dyland.app/Contents/MacOS/gerdoo-dyland          # mock Now Playing
DYLAND_DEBUG_SECTION=fileShelf ./gerdoo-dyland.app/Contents/MacOS/gerdoo-dyland # open a section at launch
DYLAND_DEBUG_SHELF_SEED="/path/a:/path/b" ./gerdoo-dyland.app/Contents/MacOS/gerdoo-dyland
```

Logs go to the unified log under the `com.gerdoo.dyland` subsystem, split into `app`, `notch`, `media`, `shelf`, `clipboard`, `actions`, and `settings` categories:

```bash
log stream --predicate 'subsystem == "com.gerdoo.dyland"' --info
```

The project uses Xcode's file-system-synchronized groups, so new source files are picked up automatically — the `.pbxproj` never needs editing.

## Releasing

CI does the work. Every push and pull request runs the test suite and a clean Release build that fails on any Swift warning.

To cut a release:

1. Bump `MARKETING_VERSION` in `gerdoo-dyland.xcodeproj/project.pbxproj` (both the Debug and Release configurations of the app target — it is the only place the version lives).
2. Write the notes at `docs/release-notes/vX.Y.Z.md`.
3. Merge that through a pull request, then tag the merge commit and push the tag:

```bash
git tag -a vX.Y.Z -m "gerdoo-dyland X.Y.Z" && git push origin vX.Y.Z
```

`.github/workflows/release.yml` takes it from there: it refuses to publish if the tag disagrees with `MARKETING_VERSION`, runs the tests, builds arm64 Release, packages the DMG, verifies the signature and architecture inside the mounted image, and publishes the GitHub release using your notes file. A tag pushed without a notes file still publishes, using GitHub's generated summary.

No signing secrets are needed: the app is ad-hoc signed, so CI builds it with no certificate in the runner.
