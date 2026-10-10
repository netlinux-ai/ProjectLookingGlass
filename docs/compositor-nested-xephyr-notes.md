# Compositor mode in nested Xephyr: first end-to-end run

Date: 2026-10-10. JDK 21, Gradle 8.14, Ubuntu 26.04. This was the first
end-to-end run of compositor mode recorded in `x11-compositor-spike-roadmap.md`.

## How to run

```
Xephyr :5 -screen 960x540 -glamor -ac -nolisten tcp -title lg3d-xephyr &
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 ./run-lg3d.sh --nested :5
DISPLAY=:5 xterm &
```

The target display must have no other window manager. Use a spare display
number; do not reuse one belonging to another session.

## Problems found and fixed (branches, in stacking order)

1. `fix/compositor-nested-xephyr`
   - `WinSysAWT` cursor-image listener methods threw "Not Implemented" at startup.
   - Escher rethrows async X errors on its reader thread; `BAD_PIXMAP` killed
     it and the event loop then spun on an NPE (hundreds of MB of log). Now
     `ignore_error(BAD_PIXMAP)`, and the loop exits if the connection is lost.
2. `fix/compositor-manual-redirect`
   - `RedirectSubwindows(root, Automatic)` leaves the server painting every
     client on screen, so each xterm appeared twice (flat plus 3D). Windows are
     now redirected one by one in Manual mode, so only lg3d draws them.
3. `fix/compositor-own-window`
   - `Component.getPeer()` is gone on JDK 21, so lg3d could not find its own
     window id. It is now recognised by title.
   - The own window can be mapped and redirected before its title is known; a
     redirected own window is never painted, giving a black screen. Recognising
     it now undoes any redirect (`teardownDamageForWindow`).

## Verified

- 3D desktop is displayed with a single composited xterm.
- Keystrokes (xdotool on :5) reach the xterm; clicks reach the 3D scene.

## Debugging tips

- A window is redirected if `XCompositeNameWindowPixmap` on it succeeds from a
  second client (BadMatch means not redirected).
- Black root capture while a direct capture of the window shows content
  means the window is redirected.
- `Xephyr -glamor` here ran llvmpipe (software GL).

## Not yet tested

3D rotation, frame rate, the NVIDIA GPU path on a real display, an unexplained
stray `^Z` before typed text, and the `Unsupported extension event: 152` warning.
