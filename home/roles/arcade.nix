# home/roles/arcade.nix
# Arcade cabinet applications and X session. Imported by the machine-local
# `arcade` user. Composed atop the `cli` role (NOT `desktop`) so the kiosk login
# gets a shell without the desktop app suite.
#
# ROMs are out-of-band content at /mnt/roms/<system>/ (see ADR-0010) — this
# role describes how to launch them, never the ROM files themselves.
{
  pkgs,
  lib,
  config,
  ...
}: let
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

  # Per-system emulator definitions. core = the libretro .so filename inside
  # retroarchWithCores; the rompath is /mnt/roms/<name> (the on-drive folder).
  emulators = {
    nes = {
      core = "mesen_libretro.so";
      romext = ".nes;.zip";
      system = "Nintendo Entertainment System";
    };
    snes = {
      core = "snes9x_libretro.so";
      romext = ".sfc;.smc;.zip";
      system = "Super Nintendo";
    };
    gameboy = {
      core = "mgba_libretro.so";
      romext = ".gb;.gbc;.zip";
      system = "Game Boy";
    };
    genesis = {
      core = "genesis_plus_gx_libretro.so";
      romext = ".md;.gen;.bin;.zip";
      system = "Sega Genesis";
    };
    atari2600 = {
      core = "stella_libretro.so";
      romext = ".a26;.bin;.zip";
      system = "Atari 2600";
    };
  };

  # Render one attract-mode emulator .cfg. `[romfilename]` is attract-mode's
  # own token (literal, not Nix) — substituted with the selected ROM at launch.
  mkEmulatorCfg = name: {
    core,
    romext,
    system,
  }: ''
    executable           ${retroarchWithCores}/bin/retroarch
    args                 -L ${retroarchWithCores}/lib/retroarch/cores/${core} "[romfilename]"
    rompath              /mnt/roms/${name}
    romext               ${romext}
    system               ${system}
  '';

  # Initial attract.cfg content, rendered from structured data (see
  # ./arcade/attract-cfg.nix) so attract-mode's tab-indented format lives in a
  # renderer, not as hand-maintained whitespace. attract-mode REWRITES this
  # file at runtime, so it is seeded once by the activation script below and
  # owned by attract-mode thereafter (ADR-0010).
  attractCfgSeed = import ./arcade/attract-cfg.nix {inherit lib emulators;};
in {
  imports = [
    ./cli.nix
  ];

  home = {
    packages = [
      pkgs.attract-mode
      retroarchWithCores
      pkgs.mame
      pkgs.matchbox
    ];

    # X session: start a featherweight WM in the background (handles focus/
    # fullscreen when emulators spawn their own windows), then exec the
    # front-end. When attract-mode exits, X exits.
    # Plus the attract-mode emulator definitions (read-only managed files —
    # attract-mode reads but does not rewrite these).
    file =
      {
        ".xinitrc" = {
          executable = true;
          text = ''
            #!/bin/sh
            ${pkgs.matchbox}/bin/matchbox-window-manager &
            exec ${pkgs.attract-mode}/bin/attract
          '';
        };
      }
      // lib.mapAttrs'
      (name: def:
        lib.nameValuePair ".attract/emulators/${name}.cfg" {
          text = mkEmulatorCfg name def;
        })
      emulators;

    # Seed attract.cfg once (writable thereafter — see attractCfgSeed comment).
    # entryAfter writeBoundary so it runs after home-manager writes the managed
    # emulator files.
    activation.seedAttractCfg = lib.hm.dag.entryAfter ["writeBoundary"] ''
      attractCfg="${config.home.homeDirectory}/.attract/attract.cfg"
      if [ ! -e "$attractCfg" ]; then
        run mkdir -p "${config.home.homeDirectory}/.attract"
        run cp ${pkgs.writeText "attract.cfg.seed" attractCfgSeed} "$attractCfg"
        run chmod u+rw "$attractCfg"
      fi
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
