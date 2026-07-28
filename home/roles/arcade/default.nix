# home/roles/arcade/default.nix
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

  # MAME's ROM directory. Referenced twice below, for two different consumers:
  # attract-mode scans it to build the romlist, and MAME itself searches it to
  # resolve a clone's parent set. Not redundancy — one source, two readers.
  mameRomPath = "/mnt/roms/mame";

  # Build a RetroArch-backed emulator definition from a libretro core filename.
  # `core` is the .so inside retroarchWithCores; the rompath is /mnt/roms/<name>
  # (the on-drive folder). RetroArch takes a full ROM path, hence
  # `[romfilename]`.
  mkRetroArchEmulator = {
    core,
    romext,
    system,
  }: {
    inherit romext system;
    executable = "${retroarchWithCores}/bin/retroarch";
    args = ''-L ${retroarchWithCores}/lib/retroarch/cores/${core} "[romfilename]"'';
  };

  # Per-system emulator definitions. Each entry carries its own executable and
  # args, so RetroArch cores and standalone emulators (MAME) share one renderer
  # — attract-mode has no core/emulator distinction, it just wants a command.
  emulators = {
    nes = mkRetroArchEmulator {
      core = "mesen_libretro.so";
      romext = ".nes;.zip";
      system = "Nintendo Entertainment System";
    };
    snes = mkRetroArchEmulator {
      core = "snes9x_libretro.so";
      romext = ".sfc;.smc;.zip";
      system = "Super Nintendo Entertainment System";
    };
    gameboy = mkRetroArchEmulator {
      core = "mgba_libretro.so";
      romext = ".gb;.gbc;.zip";
      system = "Nintendo Game Boy";
    };
    genesis = mkRetroArchEmulator {
      core = "genesis_plus_gx_libretro.so";
      romext = ".md;.gen;.bin;.zip";
      system = "Sega Genesis";
    };
    atari2600 = mkRetroArchEmulator {
      core = "stella_libretro.so";
      romext = ".a26;.bin;.zip";
      system = "Atari 2600";
    };

    # Standalone MAME, not a libretro core (see CONTEXT.md "Core").
    #
    # `args` passes MAME the short name (`[name]`) plus an explicit -rompath,
    # NOT a full file path: this is a split set where clones are separate
    # archives, and MAME must be able to *search* rompath to find a clone's
    # parent. Passing a full path works for parents and fails silently for
    # clones — the worst failure mode.
    #
    # `<DIR>` in romext exposes the CHD-based games, which are directories
    # (e.g. NAOMI/Atomiswave GD-ROM titles) rather than archives.
    #
    # `system Arcade` and `info_source listxml` match attract-mode's own
    # generated template. info_source is what makes attract-mode shell out to
    # `mame -listxml` for real titles and metadata when building the romlist;
    # the `system` value is a display label, not the trigger.
    mame = {
      executable = "${pkgs.mame}/bin/mame";
      args = ''-rompath ${mameRomPath} "[name]"'';
      romext = ".7z;<DIR>";
      system = "MAME";
      infoSource = "listxml";
    };
  };

  # Render one attract-mode emulator .cfg from a definition. Bracketed tokens
  # in `args` (`[romfilename]`, `[name]`) are attract-mode's own — literal here,
  # substituted with the selected ROM at launch.
  #
  # `info_source` is optional and emitted only when the entry sets it, so the
  # RetroArch files stay byte-identical to what the cabinet already has.
  mkEmulatorCfg = name: {
    executable,
    args,
    romext,
    system,
    infoSource ? null,
  }:
    ''
      executable           ${executable}
      args                 ${args}
      rompath              /mnt/roms/${name}
      romext               ${romext}
      system               ${system}
    ''
    + lib.optionalString (infoSource != null) ''
      info_source          ${infoSource}
    '';

  # Initial attract.cfg content, rendered from structured data (see
  # ./arcade/attract-cfg.nix) so attract-mode's tab-indented format lives in a
  # renderer, not as hand-maintained whitespace. attract-mode REWRITES this
  # file at runtime, so it is seeded once by the activation script below and
  # owned by attract-mode thereafter (ADR-0010).
  attractCfgSeed = import ./attract-cfg.nix {inherit lib emulators;};
in {
  imports = [
    ../cli.nix
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
