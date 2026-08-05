# home/modules/retroarch/default.nix
#
# Per-core input remaps for RetroArch, which home-manager's upstream
# programs.retroarch does not cover — it handles packaging (cores, a global
# settings attrset) and nothing about input.
#
# This module therefore *extends* the upstream option rather than redeclaring
# it: it adds `programs.retroarch.remaps` and sets two upstream settings that
# managed remap files cannot work without. Enabling cores stays the caller's
# job, so a consumer's console lineup is stated in one place.
#
# Per-core files live alongside this one (./nes.nix and friends) and are
# imported unconditionally — an unread .rmp costs a symlink and nothing else,
# so they do not check whether their core is enabled.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.retroarch;

  # RetroArch names remap files after the core's *runtime* library_name, not
  # its package or library filename: config_load_remap() builds
  # <dir>/<library_name>/<library_name>.rmp. The string is unguessable — it has
  # irregular casing and can contain spaces — so each core file states its own.
  # Relative to XDG config home: xdg.configFile writes there, and RetroArch is
  # told the absolute path via input_remapping_directory below.
  remapSubdir = "retroarch/config/remaps";
  remapDir = "${config.xdg.configHome}/${remapSubdir}";

  # Order is libretro's RETRO_DEVICE_ID_JOYPAD_* enum, which is what a .rmp
  # value actually is. Names match RetroArch's own key_strings table
  # (configuration.c) so a remap reads the way the file is written.
  retropadIndex = {
    b = 0;
    y = 1;
    select = 2;
    start = 3;
    up = 4;
    down = 5;
    left = 6;
    right = 7;
    a = 8;
    x = 9;
    l = 10;
    r = 11;
    l2 = 12;
    r2 = 13;
    l3 = 14;
    r3 = 15;
  };

  buttonNames = lib.attrNames retropadIndex;

  # `-1` is RetroArch's "unmapped"; any other value is the index of the button
  # this one should act as.
  renderRemap = ports:
    lib.concatStringsSep "\n" (lib.mapAttrsToList
      (from: to: ''input_player1_btn_${from} = "${toString (
          if to == null
          then -1
          else retropadIndex.${to}
        )}"'')
      ports);

  remapType = lib.types.submodule ({name, ...}: {
    options = {
      coreName = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = ''
          The core's `library_name`, as returned by `retro_get_system_info`.
          Names both the remap directory and the file inside it.

          Read it from the core rather than guessing — `Genesis Plus GX` and
          `mGBA` follow from neither the package name nor the library filename.
        '';
        example = "Genesis Plus GX";
      };

      buttons = lib.mkOption {
        type = lib.types.attrsOf (lib.types.nullOr (lib.types.enum buttonNames));
        default = {};
        description = ''
          RetroPad button remaps for player 1, as `from = "to"`. A `null` value
          unmaps the button.

          Both sides are RetroPad buttons, not physical ones: the mapping from
          the actual device to the RetroPad is autoconfig's job. So this
          expresses "on this system, the button autoconfig calls X should act
          as Y".
        '';
        example = {
          a = "b";
          x = "y";
          l2 = null;
        };
      };
    };
  });

  activeRemaps = lib.filterAttrs (_: r: r.buttons != {}) cfg.remaps;
in {
  # Per-core files, imported unconditionally: an unread .rmp costs a symlink
  # and nothing else, so they do not guard on whether their core is enabled.
  # Which cores to *build* stays the caller's decision.
  imports = [
    ./nes.nix
    ./snes.nix
    ./gameboy.nix
    ./genesis.nix
    ./atari2600.nix
  ];

  options.programs.retroarch.joypadAutoconfig = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default = pkgs.retroarch-joypad-autoconfig or null;
    defaultText = lib.literalExpression "pkgs.retroarch-joypad-autoconfig";
    description = ''
      Package supplying RetroArch's joypad autoconfig profiles, pointed at by
      `joypad_autoconfig_dir`. Set to `null` to leave the setting alone.

      RetroArch itself ships none, and without them a pad it has no built-in
      SDL mapping for is left on a fallback assignment: buttons that should
      differ can behave identically and others do nothing at all. Profiles map
      a physical device onto the RetroPad, which is the layer *beneath*
      {option}`remaps` — a remap cannot recover a button the pad never
      delivered.
    '';
  };

  options.programs.retroarch.remaps = lib.mkOption {
    type = lib.types.attrsOf remapType;
    default = {};
    description = ''
      Per-core input remaps, keyed by any convenient short name — the file path
      comes from each entry's {option}`coreName`.

      RetroArch resolves remaps first-match-wins across game, content-directory
      and core scope, and a narrower file *replaces* rather than merges with a
      broader one. These are core-scope files, so they always apply, but any
      game-specific remap made on the device will shadow one entirely.
    '';
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Autoconfig applies whether or not any remap is declared: it is what maps
    # a physical pad onto the RetroPad at all, and a device with no profile
    # falls back to an assignment that can leave buttons indistinguishable or
    # dead. Independent of remaps, which act one layer above it.
    (lib.mkIf (cfg.joypadAutoconfig != null) {
      programs.retroarch.settings.joypad_autoconfig_dir =
        lib.mkDefault "${cfg.joypadAutoconfig}/share/libretro/autoconfig";
    })

    (lib.mkIf (activeRemaps != {}) {
      # mkForce rather than a plain assignment: these are preconditions for a
      # managed remap, not preferences. With remap_save_on_exit on, RetroArch
      # overwrites the store symlink; with sort-by-controller on, it reads
      # <core>/<device>.rmp and never sees these files. Asserting instead
      # cannot work — this module is one of the definitions being merged, so it
      # would only ever read back its own value.
      programs.retroarch.settings = {
        remap_save_on_exit = lib.mkForce "false";
        input_remap_sort_by_controller_enable = lib.mkForce "false";
        input_remapping_directory = lib.mkDefault remapDir;
      };

      xdg.configFile = lib.mapAttrs' (_: r:
        lib.nameValuePair
        "${remapSubdir}/${r.coreName}/${r.coreName}.rmp"
        {text = renderRemap r.buttons + "\n";})
      activeRemaps;
    })
  ]);
}
