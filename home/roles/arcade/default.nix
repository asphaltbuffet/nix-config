# home/roles/arcade/default.nix
# Arcade cabinet applications and X session. Imported by the machine-local
# `arcade` user. Composed atop the `cli` role (NOT `desktop`) so the kiosk login
# gets a shell without the desktop app suite.
#
# ROMs are out-of-band content at /mnt/roms/<system>/ (see ADR-0010) — this
# role describes how to launch them, never the ROM files themselves.
{
  config,
  pkgs,
  lib,
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

  media = import ./media.nix;

  # Expand a system's slot list into the absolute paths the module wants. The
  # module imposes no directory convention, so this cabinet's convention
  # (<root>/<system>/<slot>) lives here.
  artworkFor = name:
    lib.genAttrs media.systems.${name}.slots
    (slot: "${media.root}/${name}/${slot}");

  # Cosmo layout per display: MAME gets the arcade layout, consoles get the
  # snes-n64 layout, which requests box/cart art rather than marquee/flyer.
  layoutFor = name:
    if name == "mame"
    then "cosmo-arcade"
    else "cosmo-snes-n64";
in {
  imports = [
    ../cli.nix
    ../../modules/attract-mode
  ];

  home = {
    # attract-mode itself is installed by programs.attract-mode; listing it here
    # too would collide in the profile if its `package` option were ever
    # overridden.
    packages = [
      retroarchWithCores
      pkgs.mame
      pkgs.matchbox
    ];

    # X session: start a featherweight WM in the background (handles focus/
    # fullscreen when emulators spawn their own windows), then exec the
    # front-end. When attract-mode exits, X exits. Session launch is the
    # role's concern (ADR-0014), not the attract-mode module's.
    file = {
      ".xinitrc" = {
        executable = true;
        text = ''
          #!/bin/sh
          ${pkgs.matchbox}/bin/matchbox-window-manager &
          exec ${config.programs.attract-mode.package}/bin/attract
        '';
      };
    };
  };

  programs.attract-mode = {
    enable = true;
    manageConfig = true;

    settings = {
      general = {
        selection_max_step = "128";
        confirm_favourites = "yes";
      };
      sound = {
        sound_volume = "100";
        ambient_volume = "100";
        movie_volume = "100";
      };
    };

    # Keyboard plus first-joystick defaults, to be remapped to real cabinet
    # hardware through attract-mode's own configure menu.
    inputMap = {
      up = ["Up" "Joy0 Up"];
      down = ["Down" "Joy0 Down"];
      left = ["Left" "Joy0 Left"];
      right = ["Right" "Joy0 Right"];
      select = ["Return" "Joy0 Button0"];
      back = ["Escape" "Joy0 Button1"];
      exit = ["LControl+Escape" "Joy0 Button7"];
      configure = "Tab";
      prev_display = "LControl+Left";
      next_display = "LControl+Right";
      prev_letter = "LShift+Up";
      next_letter = "LShift+Down";
    };

    # Boot to the system wheel rather than resuming whichever display was last
    # open, and render that wheel with cosmo's systems layout.
    startupMode = "displays_menu";
    menuLayout = "cosmo-systems";

    # Artwork belongs on the EMULATOR, not the display: attract-mode resolves it
    # via FeEmulatorInfo::get_artwork, so paths declared only on a display are
    # never consulted and every lookup silently returns nothing.
    emulators = lib.mapAttrs (name: def:
      {
        inherit (def) executable args system;
        romPath = "/mnt/roms/${name}";
        romExt = def.romext;
        artwork = artworkFor name;
      }
      // lib.optionalAttrs (def ? infoSource) {inherit (def) infoSource;})
    emulators;

    # One display per emulator is this cabinet's convention, not attract-mode's.
    # Keyed by the emulator's `system` label (e.g. "MAME") rather than the
    # emulator's short name (e.g. "mame"): the module renders `display\t<key>`
    # verbatim, and that string is the join key art lookup depends on
    # (ADR-0012) — it must come out as "MAME", not "mame".
    displays = lib.mapAttrs' (name: def:
      lib.nameValuePair def.system {
        layout = layoutFor name;
        romlist = name;
      })
    emulators;
  };

  # On the autologin tty (tty1) with no X yet, launch the graphical session.
  # Guarded so SSH logins and other TTYs get a normal shell.
  programs.zsh.loginExtra = ''
    if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
      exec startx
    fi
  '';
}
