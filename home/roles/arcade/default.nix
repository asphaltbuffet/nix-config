# home/roles/arcade/default.nix
# Arcade cabinet applications and X session. Imported by the machine-local
# `arcade` user. Composed atop the `cli` role (NOT `desktop`) so the kiosk login
# gets a shell without the desktop app suite.
#
# ROMs are out-of-band content at /mnt/roms/<system>/ (see ADR-0010) — this
# role describes how to launch them, never the ROM files themselves.
{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  # The RetroArch build carrying this cabinet's console cores, assembled by
  # home-manager's own programs.retroarch from the `cores` set below. Read back
  # here (rather than built locally) so the emulator definitions and the
  # installed package can never diverge.
  retroarchWithCores = config.programs.retroarch.finalPackage;

  # MAME's ROM directory. Referenced twice below, for two different consumers:
  # attract-mode scans it to build the romlist, and MAME itself searches it to
  # resolve a clone's parent set. Not redundancy — one source, two readers.
  mameRomPath = "/mnt/roms/mame";

  # Build a RetroArch-backed emulator definition from a libretro core filename.
  # `core` is the .so inside retroarchWithCores; the rompath is /mnt/roms/<name>
  # (the on-drive folder). RetroArch takes a full ROM path, hence
  # `[romfilename]`.
  #
  # `infoSource = "thegamesdb.net"` is what makes `attract --scrape-art <emu>`
  # do anything: the scraper is dispatched on info_source, and the empty default
  # hits `case None: break;` — no scraper, no error, no output. Scanning a plain
  # directory of ROMs yields only Name/Title/Emulator, so without this the
  # Players, Year, Manufacturer and Overview fields stay blank and any layout
  # panel bound to them renders empty.
  # `core` is the nixpkgs `libretro.<attr>` name, which drives both
  # `cores.<attr>.enable` and the -L path — but the two are not spelled the
  # same. nixpkgs hyphenates (`genesis-plus-gx`) while the installed library
  # underscores (`genesis_plus_gx_libretro.so`), hence the substitution.
  #
  # A core has a *third* name, the `library_name` it reports at runtime
  # ("Genesis Plus GX", "Snes9x", "mGBA"). It is derivable from neither of the
  # others — irregular casing, and one contains spaces — and is not needed
  # here; it names the remap directory and belongs to the retroarch module.
  mkRetroArchEmulator = {
    core,
    romext,
    system,
  }: {
    inherit core romext system;
    infoSource = "thegamesdb.net";
    executable = "${retroarchWithCores}/bin/retroarch";
    args = ''-L ${retroarchWithCores}/lib/retroarch/cores/${lib.replaceStrings ["-"] ["_"] core}_libretro.so "[romfilename]"'';
  };

  # Per-system emulator definitions. Each entry carries its own executable and
  # args, so RetroArch cores and standalone emulators (MAME) share one renderer
  # — attract-mode has no core/emulator distinction, it just wants a command.
  emulators = {
    nes = mkRetroArchEmulator {
      core = "mesen";
      # Mesen also accepts .fds, .unf and .unif (verified from the core's own
      # retro_get_system_info). .fds additionally needs a Famicom Disk System
      # BIOS on the cabinet, which nothing here provides — scanning it only
      # lists the games.
      romext = ".nes;.fds;.unf;.unif;.zip";
      system = "Nintendo Entertainment System";
    };
    snes = mkRetroArchEmulator {
      core = "snes9x";
      romext = ".sfc;.smc;.swc;.fig;.bs;.zip";
      system = "Super Nintendo Entertainment System";
    };
    gameboy = mkRetroArchEmulator {
      core = "mgba";
      romext = ".gb;.gbc;.zip";
      system = "Nintendo Game Boy";
    };
    genesis = mkRetroArchEmulator {
      core = "genesis-plus-gx";
      # Deliberately narrower than the core. Genesis Plus GX also accepts
      # .sms/.gg/.sg (Master System, Game Gear, SG-1000) and .cue/.iso/.chd
      # (Sega CD) — but this is the "Sega Genesis" system: one display, one
      # romlist, one Retrorama asset folder. Scanning those would fold four
      # consoles into it, and Sega CD needs a BIOS nothing here configures.
      # Adding them is a lineup change (emulators + media.nix + romlist),
      # not an extension change.
      romext = ".md;.gen;.smd;.bin;.zip";
      system = "Sega Genesis";
    };
    atari2600 = mkRetroArchEmulator {
      core = "stella";
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
      executable = "${config.programs.mame.finalPackage}/bin/mame";
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
  #
  # Retrorama reads only the `snap` and `flyer` artwork slots. Box art is synced
  # under `boxart`, so point `flyer` at that same directory rather than syncing
  # 20GB a second time under another name. MAME has no box art, so it keeps
  # `snap` alone and its flyer panel stays empty.
  artworkFor = name: let
    base =
      lib.genAttrs media.systems.${name}.slots
      (slot: "${media.root}/${name}/${slot}");
  in
    base
    // lib.optionalAttrs (lib.elem "boxart" media.systems.${name}.slots) {
      flyer = "${media.root}/${name}/boxart";
    };

  # Retrorama is one layout for every display; which system's assets it uses
  # comes from a per-display `system` option (see displays below), not from
  # separate layout directories the way cosmo worked.
  retroramaLayout = "retrorama";
in {
  imports = [
    ../cli.nix
    ../../modules/attract-mode
    ../../modules/mame
    ../../modules/retroarch
  ];

  home = {
    # attract-mode, RetroArch and MAME are each installed by their own module
    # (programs.attract-mode / programs.retroarch / programs.mame). Listing any
    # of them here too would collide in the profile if its `package` option were
    # ever overridden.
    packages = [
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

  programs = {
    # Standalone MAME for arcade. No extraArgs yet — the wrapper exists so that
    # the -ctrlr flag and the file it names can be derived from one value when
    # control config lands (ADR-0017); a mismatch there is fatal, not degraded.
    mame = {
      enable = true;

      # Hide the USB console pads from MAME. They are for the RetroArch
      # systems; MAME should only ever see the panel.
      #
      # This is not a preference — it protects the mapping below. SDL sorts
      # recognised game controllers ahead of plain joysticks, and the Retrolink
      # has an SDL mapping while the Xin-Mo does not. Verified on the cabinet:
      # hot-plugging the pads appends them as devices 3 and 4, but rebooting
      # with them attached makes them 1 and 2 and pushes the panel to 3 and 4 —
      # at which point every JOYCODE_1/2 binding here silently drives the pads
      # and the panel goes dead, with no error.
      ignoreDevices = [
        "0x0079/0x0011"
        "0x0079/0x0006"
      ]; # Retrolink SNES Controller

      # Xin-Mo dual-arcade encoder: two devices, so JOYCODE_1_* and JOYCODE_2_*
      # address the two players. Button order follows the kernel's BTN_* order,
      # which on this panel runs left-to-right along the top row then the
      # bottom: BTN_TRIGGER..BTN_TOP are 1-4, BTN_TOP2..BTN_BASE2 are 5-8, then
      # Select (9) and Start (10).
      #
      # The joystick reports ABS_X/ABS_Y with range +/-1 — digital, not analog —
      # so it needs the _SWITCH axis codes rather than analog ones.
      #
      # Only the `default` scope is populated. MAME's own per-driver defaults
      # are sensible for most of the set, and scopes accumulate, so per-family
      # rules can be added to bySourceFile as real play turns up games that
      # want something different.
      controls.default.ports = let
        # Columns 1-3 of both rows are the conventional six-button fighting
        # layout. Column 4 of each row (buttons 4 and 8) is deliberately left
        # out of the game ports and used for UI below.
        player = n: {
          "P${n}_JOYSTICK_UP" = "JOYCODE_${n}_YAXIS_UP_SWITCH";
          "P${n}_JOYSTICK_DOWN" = "JOYCODE_${n}_YAXIS_DOWN_SWITCH";
          "P${n}_JOYSTICK_LEFT" = "JOYCODE_${n}_XAXIS_LEFT_SWITCH";
          "P${n}_JOYSTICK_RIGHT" = "JOYCODE_${n}_XAXIS_RIGHT_SWITCH";
          "P${n}_BUTTON1" = "JOYCODE_${n}_BUTTON1";
          "P${n}_BUTTON2" = "JOYCODE_${n}_BUTTON2";
          "P${n}_BUTTON3" = "JOYCODE_${n}_BUTTON3";
          "P${n}_BUTTON4" = "JOYCODE_${n}_BUTTON5";
          "P${n}_BUTTON5" = "JOYCODE_${n}_BUTTON6";
          "P${n}_BUTTON6" = "JOYCODE_${n}_BUTTON7";
        };
      in
        player "1"
        // player "2"
        // {
          START1 = "JOYCODE_1_BUTTON10";
          START2 = "JOYCODE_2_BUTTON10";
          COIN1 = "JOYCODE_1_BUTTON9";
          COIN2 = "JOYCODE_2_BUTTON9";

          # The cabinet has no keyboard, so MAME's keyboard-only UI defaults
          # (Tab, Esc) are unreachable. The reserved right-hand column of P1's
          # panel drives the menu instead.
          UI_MENU = "JOYCODE_1_BUTTON4";
          UI_CANCEL = "JOYCODE_1_BUTTON8";
        };
    };

    # The cabinet's console lineup, derived from `emulators` so it is stated
    # once. Which consoles exist is the role's call; how each core is packaged
    # is home-manager's.
    retroarch = {
      enable = true;
      cores =
        lib.mapAttrs' (_: def: lib.nameValuePair def.core {enable = true;})
        (lib.filterAttrs (_: def: def ? core) emulators);
    };

    attract-mode = {
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

      # Boot to the system selector rather than resuming whichever display was
      # last open.
      #
      # The displays menu is rendered by its own layout, and Retrorama ships none —
      # its layout.nut assumes a game list and has no menu handling. `Cools` is
      # bundled with attract-mode, declares a 320x240 layout size (so attract-mode
      # scales it to fit rather than distorting, unlike cosmo's unset dimensions),
      # and reads the `wheel` and `snap` slots — which is what ~/.attract/menu-art
      # holds for the six systems.
      startupMode = "displays_menu";
      menuLayout = "Cools";

      # Scraper API key, read at activation from /run/agenix so it stays
      # encrypted in the repo. Without it the console emulators' thegamesdb.net
      # scraper fails with 403 (attract-mode's built-in key was revoked
      # upstream), surfacing as "Error parsing json, text:" on --build-romlist.
      #
      # No null fallback: this role is only ever evaluated as part of the
      # cabinet's NixOS config, and silently omitting the key would restore
      # exactly the broken-scraper behaviour this fixes, with no diagnostic.
      thegamesdbKeyFile = osConfig.age.secrets."arcade/thegamesdbKey".path;

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
      # Retrorama's `system` is a layout option declared per_display. Such options
      # live inside the display section, but NOT under their own name — a display
      # accepts only layout, romlist, in_cycle, in_menu, filter and global_filter.
      # They go through the literal key `param`, whose value carries the option
      # name and its value space-separated (FeScriptConfigurable::process_setting,
      # indexString = "param"). Writing `system Arcade` directly earns
      # "Unrecognized display setting" on every config load.
      displays = lib.mapAttrs' (name: def:
        lib.nameValuePair def.system {
          layout = retroramaLayout;
          romlist = name;
          extraSettings.param = [
            "system ${media.systems.${name}.retroramaSystem}"
            # The layout draws rows from y=390 at 23px each, and the panel runs to
            # roughly y=1000; the default 20 rows stop at 850 and leave a visible
            # gap. 26 rows reach 988.
            "gameListElements 26"
          ];
        })
      emulators;
    };

    # On the autologin tty (tty1) with no X yet, launch the graphical session.
    # Guarded so SSH logins and other TTYs get a normal shell.
    zsh.loginExtra = ''
      if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
        exec startx
      fi
    '';
  };
}
