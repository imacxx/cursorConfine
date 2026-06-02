# CursorConfine

Lock your mouse cursor inside a window, region, or display so it can't slip
away on misclicks. Built for borderless gaming on huge monitors, but useful
for anyone who's tired of overshooting window edges.

> "Discord's screen-picker, but for trapping your cursor."

- macOS 15 (Sequoia) or newer • Apple Silicon (M-series) only
- Pure Swift + SwiftUI, zero third-party dependencies
- Menu-bar app with a full settings window
- Cmd-Tab always works; the cursor auto-releases when the target loses focus

---

## Install (end-users)

If you grabbed a `CursorConfine-x.y.z-arm64.zip` from the Releases page:

1. Double-click the zip to extract `CursorConfine.app`.
2. Drag it to `/Applications`.
3. Double-click to launch. The build is **signed with a Developer ID and
   notarized by Apple**, so it opens with no Gatekeeper warning and no trip
   through System Settings.
4. The CursorConfine main window appears. Grant **Accessibility** when the
   Permissions tab asks (this is what lets it confine the cursor) and
   optionally **Screen Recording** (window thumbnails + real titles in the
   picker, otherwise you'll see "Untitled window").

No App Store, no Apple ID, nothing phone-home.

> If you instead built an unsigned/ad-hoc zip yourself (via `./release.sh`),
> macOS will block the first launch with *"Apple could not verify…"*. Open
> **System Settings → Privacy & Security**, scroll down, and click **Open
> Anyway**. Notarized release builds (`./notarize.sh`) skip this entirely.

---

## Features

- **Four confinement modes**:
  1. **Specific window** — Discord-style picker with live thumbnails.
  2. **Active window** — follows whichever window currently has focus.
  3. **Custom region** — drag a rectangle anywhere on your desktop.
  4. **Whole display** — pin the cursor to one monitor.
- **Auto-release on focus loss.** When you Cmd-Tab or click another app the
  cursor frees instantly; it auto-re-engages when you come back.
- **Customizable global hotkeys**: toggle, pick window, panic release.
- **Hold-to-release modifier**: hold ⌘ / ⌥ / ⌃ / ⇧ to temporarily free the cursor.
- **Per-app profiles**: e.g. "when League of Legends is frontmost, auto-confine."
- **Visual overlays** (optional): dim everything outside the region, draw a
  colored border around it.
- **Sounds & notifications** on lock/unlock (toggleable).
- **Launch at login** (`SMAppService`) and start-armed-on-launch options.
- **Multi-monitor aware** — everything in the global top-left-origin point space,
  Retina-correct.
- **Edge inset** slider — shrink the clamp rect on all sides for games that
  overshoot a few pixels.
- **Panic key** that always works — never any way to deadlock the cursor.
- **Pause during screen-saver / lock-screen**, resume on wake.

---

## Build & run

You don't need Xcode — just the command-line tools (`xcode-select --install`).
The build script uses `swift build` plus a tiny bash wrapper to assemble the
`.app` bundle and ad-hoc sign it.

```bash
./build.sh                                  # → build/CursorConfine.app
open build/CursorConfine.app
```

Build the underlying Swift package directly (skips the bundle / signing step):

```bash
swift build -c release --arch arm64
```

Run unit tests:

```bash
swift test
```

### Cut a release

For public distribution, build the **signed + notarized** zip so users can
just double-click — no "Open Anyway":

```bash
./notarize.sh                               # → dist/CursorConfine-x.y.z-arm64.zip
```

This reuses `build.sh`, re-signs the bundle with the **Developer ID
Application: Nicky Audenaerde (RU6DL9DFXW)** identity + hardened runtime,
submits to Apple's notary service, staples the ticket, and packages the zip.

Prereqs (one-time): the Developer ID cert in your login keychain, and a
notarytool keychain profile. By default the script reuses the same Apple
account's `elyra-notary` profile; override with `NOTARY_PROFILE=…` (see the
header of `notarize.sh` for the `store-credentials` command).

Quick unsigned zip (local testing only — recipients hit the "Open Anyway"
step):

```bash
./release.sh                                # → dist/CursorConfine-x.y.z-arm64.zip
```

Both scripts use `ditto` (not `zip`) so the code signature survives the
round-trip. The version comes from `CFBundleShortVersionString` in
`Info.plist` — bump it there before cutting a release.

(Optional) one-liner with Swift only, no script:

```bash
swift build -c release --arch arm64 && \
  mkdir -p build/CursorConfine.app/Contents/MacOS && \
  mkdir -p build/CursorConfine.app/Contents/Resources && \
  cp "$(swift build -c release --arch arm64 --show-bin-path)/CursorConfine" \
     build/CursorConfine.app/Contents/MacOS/CursorConfine && \
  cp Info.plist build/CursorConfine.app/Contents/Info.plist && \
  codesign --force --deep --sign - build/CursorConfine.app && \
  open build/CursorConfine.app
```

---

## First-run permissions

CursorConfine asks for one mandatory and one optional permission via the
Onboarding flow and the **Permissions** tab in the main window.

| Permission        | Why                                                                                | Required? |
|-------------------|-------------------------------------------------------------------------------------|-----------|
| Accessibility     | Install a global `CGEventTap` to clamp the cursor.                                   | Yes       |
| Screen Recording  | Live window thumbnails in the picker. Without it, window titles are masked.        | No        |

If you reject the prompt, open **System Settings → Privacy & Security →
Accessibility / Screen Recording** and add `CursorConfine.app` manually.
No quit-and-relaunch needed — `PermissionsService` polls every 1.5 s and
auto-installs the event tap the moment Accessibility flips on.

### Stable signing for development (recommended)

Without it, every `./build.sh` produces a new ad-hoc cdhash and macOS TCC
forgets your Accessibility / Screen Recording grants — you'd have to toggle
the entry in System Settings off-and-on after every rebuild.

Run **once** to generate a self-signed code-signing cert in your login
keychain (`CursorConfine Dev`):

```bash
./setup_signing_cert.sh
```

After this, `./build.sh` automatically signs with that identity (it
checks `security find-identity` and falls back to ad-hoc only if the cert
is missing). TCC trust persists across rebuilds because the code
requirement is anchored to the cert's stable public-key hash, not the
binary's cdhash. You'll still need to re-grant **once** the first time
you switch from ad-hoc to the stable identity.

---

## Default hotkeys

| Action                | Combo            |
|-----------------------|------------------|
| Toggle confinement    | **⌃⌥L**          |
| Pick window           | **⌃⌥P**          |
| Panic release         | **⌃⌥⇧⎋**         |
| Temporary release     | **Hold ⌘**       |

All hotkeys are rebindable in **Settings → Hotkeys**.

---

## Architecture (one-glance)

```
CursorConfineApp (SwiftUI @main)
└── AppDelegate (NSApplicationDelegate)
    └── AppState  (@MainActor @Observable)  — coordinator
        ├── ConfinementEngine          CGEventTap + clamp + warp
        ├── WindowService              CGWindowList enumeration / resolution
        ├── DisplayService             CGDirectDisplay enumeration
        ├── FocusMonitor               NSWorkspace + 0.5s poll
        ├── HotkeyManager              Carbon RegisterEventHotKey
        ├── ProfileStore               per-app rules
        ├── SettingsStore              UserDefaults JSON blob
        ├── PermissionsService         AX / Screen Recording status
        ├── ScreenSaverMonitor         pause when locked / asleep
        ├── SoundNotificationService   NSSound + UserNotifications
        └── LaunchAtLoginService       SMAppService.mainApp
```

All coordinates are kept in **CG global top-left-origin point space** to match
`CGEvent` locations, `CGWarpMouseCursorPosition`, `CGWindowList` bounds, and the
Accessibility API. `Geometry.swift` is the single source of truth for AppKit
(bottom-left) ↔ CG conversions.

The CGEventTap callback is intentionally **allocation-free** — it only reads
two stored properties (`activeRect`, `inset`) and one flag (`temporaryReleaseCheck`),
so it stays well under the per-event time budget that macOS enforces. When
macOS does auto-disable the tap (`tapDisabledByTimeout` / `ByUserInput`), we
re-enable it from the same callback.

---

## What was verified vs. what needs hands-on testing

Everything that doesn't require a real cursor moving in a real GUI session was
checked end-to-end. The hard-to-verify parts are clearly the cursor-clamping
behavior itself; that's GUI-only and you'll need to try it.

### Verified automatically

- `swift build -c release --arch arm64` — clean, no warnings, no errors.
- `swift test` — 24 unit tests pass: `Geometry` clamping math, coordinate
  conversions, inverted-rect handling, edge-touching semantics; `WindowSelection`
  matching scores; `Profile` → `ConfinementTarget` matching with/without title
  hints and with missing candidates; `Hotkey` codable round-trip + descriptions;
  `Settings` full codable round-trip.
- `./build.sh` — produces `build/CursorConfine.app`, ad-hoc-signed, passes
  `codesign --verify`.
- Bundle launches as a process and stays running (smoke-tested twice; ~75 MB
  RSS, no crash, TCC permission polling confirmed via `log show`).
- Standalone `swift /tmp/smoke_enum.swift` confirms `CGWindowListCopyWindowInfo`
  returns real-app windows in the current environment (12 windows found
  including a target game window).

### Needs hands-on testing (interactive GUI)

These require a logged-in macOS session, mouse input, and a window to clamp to.
None can be exercised from a script.

- **Cursor clamp itself.** Pick a window, move the mouse across the boundary —
  confirm it stops at the edge and the event location is rewritten.
- **Cmd-Tab release/re-engage.** Lock to a window, Cmd-Tab away — cursor frees;
  Cmd-Tab back — re-locks.
- **Panic hotkey.** ⌃⌥⇧⎋ at any time should release.
- **Region picker.** "Draw region…" should let you drag a rectangle and clamp to it.
- **Per-display mode.** Cursor cannot leave the chosen display.
- **Overlays.** Dim / border render correctly on a multi-monitor setup.
- **Profile auto-activate.** Create a profile for an app; bring it to focus;
  confirm auto-arm.
- **Launch at login.** Toggle on, reboot, confirm app launches.
- **Hotkey rebinding.** Capture-style picker swallows the captured combo.
- **Screen Recording-granted thumbnails.** Without it the picker still works
  but shows app icons + "Untitled window."

---

## Known limits

- **macOS 14+** required. SwiftUI's `MenuBarExtra` + `Window` scenes,
  `SCScreenshotManager`, and `Observation` framework are all macOS-13/14+.
- **Apple Silicon binary** by default. To build for Intel, replace
  `--arch arm64` in `build.sh` with `--arch x86_64` (or add both to make it
  universal).
- **Signing.** Release builds (`./notarize.sh`) are Developer ID-signed and
  notarized, so they open with no Gatekeeper prompt. Local `build.sh` /
  `release.sh` builds are ad-hoc or self-signed — macOS may show a
  "downloaded from internet" prompt; right-click the app → Open. No paid
  Apple Developer account needed for local use.
- **Window titles need Screen Recording**. Without it, the picker shows "App
  — Untitled window." Bundle ID / app name still match correctly so window
  resolution after restart still works.
- **CGWindowID is volatile.** When the app restarts we re-resolve the target
  by bundle ID + window title; if both have changed, you'll need to pick again.
- **One profile per bundle ID.** First matching `autoActivate` profile wins.
- **Carbon hotkeys** under the hood. They register at the application event
  target so the combo is system-wide and swallowed (never types into other
  apps), but a previously-running app holding the same combo will block ours.

---

## File layout

```
CursorConfine/
├── Package.swift                Swift Package manifest
├── Info.plist                   Bundle plist (NSAccessibilityUsageDescription, NSScreenCaptureUsageDescription, …)
├── build.sh                     swift build → assemble .app → ad-hoc/self-sign
├── release.sh                   build.sh → ditto into a (unsigned) distributable zip
├── notarize.sh                  build.sh → Developer ID sign → notarize → staple → zip
├── README.md                    This file
├── Sources/CursorConfine/
│   ├── CursorConfineApp.swift   @main, MenuBarExtra + Window scenes
│   ├── AppDelegate.swift        Lifecycle, overlays, intent bus
│   ├── AppState.swift           @Observable coordinator
│   ├── Models/                  ConfinementMode, ConfinementTarget, WindowInfo, Profile, Hotkey, Settings
│   ├── Services/                ConfinementEngine, WindowService, DisplayService, FocusMonitor,
│   │                            HotkeyManager, ProfileStore, SettingsStore, PermissionsService,
│   │                            WindowThumbnailService, SoundNotificationService,
│   │                            LaunchAtLoginService, ScreenSaverMonitor
│   ├── Utilities/               Geometry (clamp + AppKit↔CG conversions), Log
│   ├── Views/                   MainWindowView (sidebar) + Home / Profiles / Hotkeys /
│   │                            Appearance / General / Permissions / About / Onboarding,
│   │                            MenuBarContent, WindowPickerView
│   └── Overlays/                DimOverlayController, BorderOverlayController, RegionPickerController
└── Tests/CursorConfineTests/    Geometry, WindowSelection, Profile, Hotkey, SettingsCodable
```
