# DesktopGif

macOS app (SwiftUI + AppKit) that plays an animated **GIF** in a **borderless, draggable** window, meant to sit on the desktop like a small companion. This document explains the **user flow**, **current limitations**, and **where the code lives**.

---

## Repository layout

At the project root (next to **`DesktopGif.xcodeproj`**):

| Path | What it is |
|------|----------------|
| **`DesktopGif.xcodeproj/`** | Xcode project and shared scheme. |
| **`DesktopGif/`** | Application source and resources (see below). |
| **`README.md`** | This file. |

---

## Requirements and run

- **macOS 14+** (matches the Xcode target).
- **Full Xcode** from the App Store — not Command Line Tools only. Set **Xcode → Settings → Locations → Command Line Tools** to that Xcode if you use `xcodebuild`.

**Run:** open **`DesktopGif.xcodeproj`**, select the **DesktopGif** scheme, press **Run** (▶).

If macOS blocks an unsigned local build the first time, use **Right-click → Open** on the app in Finder, or adjust **Privacy & Security** as needed.

---

## User flow (what you see)

Nothing runs automatically at launch (no file dialog on startup).

### Step 1 — Choose display mode

**`ModeSelectionView`** shows **“Choose display mode”** with three rows:

| Control | Behavior |
|---------|----------|
| **Widget Mode** | Active (prominent). Tap to go to **Step 2**. |
| **Window Mode** | Disabled placeholder + TODO copy. Does **not** navigate. |
| **Overlay Mode** | Same as Window Mode — placeholder only. |

Only **Widget Mode** is wired today.

### Step 2 — Choose a GIF

**`GifPickerView`** shows **“Choose a GIF”** and **Select GIF…**.

- **Select GIF…** or **⌘O** (while this screen is focused) opens **`NSOpenPanel`** for `.gif` files.
- **File → Open…** (menu) does the same **only after** you completed Step 1. On the mode screen it does nothing.

### Step 3 — GIF on the desktop

If decoding succeeds, the window **resizes to the GIF’s logical size** and **`AnimatedGIFView`** plays the animation.

- **Drag** anywhere on the content to move the window (handled by **`WindowDragController`**, not a title bar).
- **Desktop → Pass clicks through** (**⌘⌥T**): when on, mouse events pass through the window; use the menu again to interact with the window.

### Typing burst (GIF speed)

**`AppModel`** installs a **local** `keyDown` monitor (keys while DesktopGif is focused) and a **global** monitor (keys in **other** apps) after macOS grants **Listen Event** / **Input Monitoring** permission. A timer smooths **`playbackSpeedMultiplier`** toward **3×** while you type and back to **1×** after a short idle. **`AnimatedGIFView`** uses ImageIO frame timing with delay ÷ multiplier.

- Approve the system prompt if shown, then ensure **DesktopGif** is enabled under **System Settings → Privacy & Security → Input Monitoring** so **global** detection works when you type in Safari, Notes, etc.
- Use menu **Typing → Refresh global key monitor** after changing permissions, or **Typing → Open Input Monitoring settings…**.

If the file cannot be read, you see **“Could not read this GIF.”**

---

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| **⌘O** | Open GIF picker (from **File** menu or when **GifPickerView**’s button is in scope). |
| **⌘⌥T** | Toggle **Pass clicks through** ( **Desktop** menu ). |

---

## Current behavior (limitations)

- **`DisplayMode.window`** and **`.overlay`** exist in the model but **do not** change window level, chrome, or stacking yet. All successful runs use the **same** configuration as today’s “desktop sticker”: borderless, transparent, level **just above** Finder’s desktop icon layer, with **`ContentView.configureDesktopWindow(_:)`**.
- **`selectedMode`** is set to **`.widget`** when you proceed from Step 1, reserved for future per-mode behavior.

---

## Source map (`DesktopGif/` target)

Swift sources are grouped under **`DesktopGif/DesktopGif/`**:

| Folder | Files | Responsibility |
|--------|--------|------------------|
| **`App/`** | `DesktopGifApp.swift` | `@main`, `WindowGroup`, menus (**File**, **Desktop**, **Typing**). |
| **`Models/`** | `AppModel.swift`, `DisplayMode.swift` | Shared state; **typing burst** monitors + **`playbackSpeedMultiplier`**; display mode enum. |
| **`Views/`** | `ContentView.swift`, `ModeSelectionView.swift`, `GifPickerView.swift`, `AnimatedGIFView.swift` | Routing UI; GIF playback via ImageIO + speed multiplier. |
| **`Windows/`** | `WindowAccessor.swift`, `WindowDragController.swift` | Attach to `NSWindow`; event-monitor-based dragging for borderless windows. |
| **`Resources/`** | `.gitkeep` | Placeholder for assets (e.g. asset catalogs, localized strings) — add files here as the app grows. |

**Coordinator:** **`ContentView`** owns **`pickGIF()`**, **`adoptGIF(at:)`**, **`syncWindowSizeToGIF(window:)`**, and **`configureDesktopWindow(_:)`**. **`GifPickerView`** only invokes a closure; it does not present **`NSOpenPanel`** itself.

---

## Command-line build

```bash
cd /path/to/DesktopGif
xcodebuild -scheme DesktopGif -configuration Debug -destination 'platform=macOS' build
```

Use the directory that contains **`DesktopGif.xcodeproj`**. If you see **`xcodebuild` requires Xcode**, install full Xcode and set the active developer directory as above.
