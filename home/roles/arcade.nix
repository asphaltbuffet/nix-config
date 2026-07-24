# home/roles/arcade.nix
# Arcade cabinet applications and X session. Imported by the machine-local
# `arcade` user. Composed atop the `cli` role (NOT `base`) so the kiosk login
# gets a shell without the desktop app suite.
#
# ROMs are out-of-band content at ~/roms/<system>/ (see ADR-0010) — this role
# describes how to launch them, never the ROM files themselves.
{pkgs, ...}: let
  # One RetroArch build carrying exactly the five console cores. Verify core
  # attr names with `nix search nixpkgs libretro` if any fails to evaluate.
  retroarchWithCores = pkgs.retroarch.withCores (cores:
    with cores; [
      mesen # NES
      snes9x # SNES
      mgba # Game Boy / GBA
      genesis-plus-gx # Sega Genesis
      stella # Atari 2600
    ]);
in {
  imports = [
    ./cli.nix
  ];

  home.packages = [
    pkgs.attract-mode
    retroarchWithCores
    pkgs.mame
    pkgs.matchbox-window-manager
  ];

  # X session: start a featherweight WM in the background (handles focus/
  # fullscreen when emulators spawn their own windows), then exec the
  # front-end. When attract-mode exits, X exits.
  home.file.".xinitrc" = {
    executable = true;
    text = ''
      #!/bin/sh
      ${pkgs.matchbox-window-manager}/bin/matchbox-window-manager &
      exec ${pkgs.attract-mode}/bin/attract
    '';
  };

  # On the autologin tty (tty1) with no X yet, launch the graphical session.
  # Guarded so SSH logins and other TTYs get a normal shell.
  programs.zsh.loginExtra = ''
    if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
      exec startx
    fi
  '';
}
