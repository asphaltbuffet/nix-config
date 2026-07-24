# Arcade cabinet runs on bare X via startx, not a Wayland kiosk

The arcade profile boots the cabinet into attract-mode over a bare X server started by `startx` from a tty1 autologin, with a featherweight window manager (matchbox) under the front-end — not a Wayland single-app kiosk (`cage`) and not a display manager + desktop like the rest of the fleet.

attract-mode is an X11/OpenGL (SFML) application with no native Wayland backend; running it under Wayland means an XWayland translation layer beneath both it and every emulator it launches. Bare X is the battle-tested retro-cabinet path with maximum compatibility for GL emulators like MAME, at the cost of wiring the autologin → startx → attract-mode chain by hand rather than via a single tidy NixOS module. matchbox is included because a WM-less session lets some emulators mishandle focus/fullscreen when they spawn their own windows; matchbox enforces one-fullscreen-window-at-a-time, which is exactly the cabinet's desired behavior.

## Considered Options

- **`cage` (Wayland single-app kiosk)** — cleanest NixOS expression (`services.cage` does autologin + launch in one module), rejected for the XWayland layer under MAME and other GL emulators.
- **Display manager + full desktop** — matches the fleet's laptop hosts, rejected as far too heavy for a kiosk and pulling in desktop services a cabinet never uses.
