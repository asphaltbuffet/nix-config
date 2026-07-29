# home/modules/attract-mode/default.nix
#
# Interface module for attract-mode (ADR-0014): declares programs.attract-mode
# rather than setting someone else's options, because home-manager has no
# upstream module for it. Written to upstream conventions so it can be
# contributed; keep it free of any assumption about a particular machine.
#
# Scope is deliberately partial — emulators, displays, the displays menu, input
# map, and general/sound settings. Filters, screensaver, and intro params are
# unimplemented; the option types are shaped so they can be added later without
# breaking changes.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.attract-mode;

  emulatorType = lib.types.submodule {
    options = {
      executable = lib.mkOption {
        type = lib.types.str;
        description = "Program attract-mode runs to launch a game.";
        example = "/run/current-system/sw/bin/mame";
      };
      args = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Arguments passed to {option}`executable`. attract-mode substitutes its
          own bracketed tokens here, such as `[romfilename]` and `[name]`; they
          are literal text as far as Nix is concerned.
        '';
        example = ''-L /path/core.so "[romfilename]"'';
      };
      romPath = lib.mkOption {
        type = lib.types.str;
        description = "Directory attract-mode scans for this system's ROMs.";
      };
      romExt = lib.mkOption {
        type = lib.types.str;
        description = ''
          Semicolon-separated file extensions to treat as ROMs. `<DIR>` matches
          directories, for systems whose games are folders rather than archives.
        '';
        example = ".zip;.7z";
      };
      system = lib.mkOption {
        type = lib.types.str;
        description = ''
          Name attract-mode shows for this system. Note this is not purely
          cosmetic: layouts commonly resolve per-system artwork by this name, so
          changing it can silently break art lookup for that system.
        '';
      };
      infoSource = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Metadata source attract-mode consults when building a romlist, e.g.
          `listxml` to shell out to MAME for real titles. Omitted when null.
        '';
      };
      artwork = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = ''
          Artwork slot name to search path. Paths are absolute; this module
          imposes no directory convention.
        '';
        example = lib.literalExpression ''{ wheel = "/srv/media/nes/wheel"; }'';
      };
    };
  };

  displayType = lib.types.submodule {
    options = {
      layout = lib.mkOption {
        type = lib.types.str;
        description = "Layout (theme) used to render this display.";
      };
      romlist = lib.mkOption {
        type = lib.types.str;
        description = ''
          Romlist this display shows, by name. Romlists are built on the target
          machine with `attract --build-romlist`; this module never generates
          them.
        '';
      };
      extraSettings = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Additional key/value lines emitted in this display's section.";
      };
    };
  };
  r = import ./render.nix {inherit lib;};

  # input_map's file format repeats the action name once per binding; the
  # option models that as a list value, so expand it back out here.
  inputMapPairs = lib.flatten (lib.mapAttrsToList (
      action: binding:
        map (b: {
          name = action;
          value = b;
        }) (lib.toList binding)
    )
    cfg.inputMap);

  # A display's settings. Note attract-mode accepts only layout, romlist,
  # in_cycle, in_menu and filter here (FeDisplayInfo::indexStrings) — artwork is
  # NOT a display setting. It is resolved from the emulator
  # (FeEmulatorInfo::get_artwork), so it lives on `emulators`, not here.
  displayPairs = d:
    [
      {
        name = "layout";
        value = d.layout;
      }
      {
        name = "romlist";
        value = d.romlist;
      }
    ]
    ++ lib.mapAttrsToList (k: v: {
      name = k;
      value = v;
    })
    d.extraSettings;

  # `menu_layout` and `startup_mode` are settings inside `general`, not sections
  # of their own — attract-mode's only top-level sections are display, sound,
  # input_map, general, plugin, saver_config, layout_config, intro_config and
  # menu_config (FeSettings::otherSettingStrings). Emitting an unknown header
  # does not start a section; the parser stays in whatever section preceded it
  # and misreads the keys that follow.
  generalExtra =
    lib.optionalAttrs (cfg.menuLayout != null) {menu_layout = cfg.menuLayout;}
    // lib.optionalAttrs (cfg.startupMode != null) {startup_mode = cfg.startupMode;};

  settingsWithGeneral =
    cfg.settings
    // lib.optionalAttrs (generalExtra != {}) {
      general = (cfg.settings.general or {}) // generalExtra;
    };

  sections =
    lib.mapAttrsToList (name: kv: {
      header = name;
      pairs =
        lib.mapAttrsToList (k: v: {
          name = k;
          value = v;
        })
        kv;
    })
    settingsWithGeneral
    ++ lib.optional (cfg.inputMap != {}) {
      header = "input_map";
      pairs = inputMapPairs;
    }
    ++ lib.mapAttrsToList (name: d: {
      header = "display";
      inherit name;
      pairs = displayPairs d;
    })
    cfg.displays;

  attractCfgText =
    r.header
    + "\n\n"
    + lib.concatStringsSep "\n" (map r.cfgSection sections);

  mkEmulatorCfg = def:
    r.header
    + "\n"
    + lib.concatStringsSep "\n" (
      [
        (r.emuLine "executable" def.executable)
        (r.emuLine "args" def.args)
        (r.emuLine "rompath" def.romPath)
        (r.emuLine "romext" def.romExt)
        (r.emuLine "system" def.system)
      ]
      ++ lib.optional (def.infoSource != null) (r.emuLine "info_source" def.infoSource)
      ++ lib.mapAttrsToList r.emuArtworkLine def.artwork
    )
    + "\n";

  # Build every configured romlist. attract-mode's --build-romlist takes several
  # emulators but writes them to ONE romlist, so this must loop rather than pass
  # the whole list at once.
  buildRomlists = pkgs.writeShellScriptBin "attract-build-romlists" ''
    set -euo pipefail
    for emu in ${lib.escapeShellArgs (lib.attrNames cfg.emulators)}; do
      echo "Building romlist: $emu"
      ${cfg.package}/bin/attract --build-romlist "$emu"
    done
  '';
in {
  options.programs.attract-mode = {
    enable = lib.mkEnableOption "attract-mode, a graphical front-end for emulators";

    package = lib.mkPackageOption pkgs "attract-mode" {};

    manageConfig = lib.mkOption {
      type = lib.types.either lib.types.bool (lib.types.enum ["seed"]);
      default = true;
      description = ''
        How `attract.cfg` is owned. `true` writes it as a read-only store
        symlink rewritten on every activation, so this module's options are the
        single source of truth. `"seed"` writes it once if absent and leaves it
        writable thereafter. `false` writes it not at all, leaving attract-mode
        to generate its own on first run — use this to manage the file by some
        other means.

        Only attract-mode's own configuration UI (the `configure` action, Tab by
        default) writes `attract.cfg`; runtime state lives in a separate file,
        `attract.am`, which this module never touches. So the only thing `true`
        costs is that settings changed through that UI do not persist. Choose
        `"seed"` if you rely on it.

        This does not affect `emulators/*.cfg`, which are always managed.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = {};
      description = ''
        Top-level `attract.cfg` sections, as section name to key/value pairs.
      '';
      example = lib.literalExpression ''
        {
          general.selection_max_step = "128";
          sound.sound_volume = "100";
        }
      '';
    };

    inputMap = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
      default = {};
      description = ''
        Action name to input binding(s). An action may have several bindings, so
        the value may be a list; attract-mode's file format repeats the key,
        which this module emits for you.

        The names `default` and `map` are reserved by attract-mode for command
        fallbacks and joystick naming, and are rejected here.
      '';
      example = lib.literalExpression ''
        {
          up = [ "Up" "Joy0 Up" ];
          configure = "Tab";
        }
      '';
    };

    menuLayout = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Layout used for the displays menu — the wheel listing configured
        displays. Emitted as `menu_layout` in the `general` section, which is
        where attract-mode reads it from; there is no `displays_menu` section.
        Null leaves attract-mode's default.
      '';
      example = "mytheme-systems";
    };

    startupMode = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["default" "launch_last_game" "displays_menu"]);
      default = null;
      description = ''
        What attract-mode shows on launch. `default` resumes the last
        selection, `launch_last_game` relaunches it, and `displays_menu` opens
        the displays menu. Null leaves attract-mode's default (`default`).
      '';
    };

    emulators = lib.mkOption {
      type = lib.types.attrsOf emulatorType;
      default = {};
      description = ''
        Emulator definitions, keyed by name. Each renders to one
        `~/.attract/emulators/<name>.cfg`. These files are always managed by
        this module, regardless of {option}`manageConfig`.
      '';
    };

    displays = lib.mkOption {
      type = lib.types.attrsOf displayType;
      default = {};
      description = ''
        Displays, keyed by name. A display is a view — a romlist, a layout, and
        artwork — and is independent of an emulator: several displays may share
        one romlist, and a romlist may span several emulators.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.inputMap ? "default") && !(cfg.inputMap ? "map");
        message = ''
          programs.attract-mode.inputMap: "default" and "map" are reserved by
          attract-mode for command fallbacks and joystick naming, and cannot be
          used as action names.
        '';
      }
      {
        # These sections are generated from their own options. Emitting them
        # from `settings` too would write a second section with the same header,
        # and attract-mode's parser would silently keep one and discard the
        # other.
        assertion = !(lib.any (s: cfg.settings ? ${s}) ["input_map" "display"]);
        message = ''
          programs.attract-mode.settings: "input_map" and "display" are
          generated from the inputMap and displays options. Set those instead of
          writing the sections by hand.
        '';
      }
      {
        # attract-mode recognises a fixed set of top-level section names. An
        # unrecognised one does NOT start a new section — the parser keeps
        # appending to the previous one and misreads its keys, which surfaces as
        # a confusing "Unrecognized ... command" error about the wrong section.
        assertion = lib.all (s:
          lib.elem s [
            "display"
            "sound"
            "input_map"
            "general"
            "plugin"
            "saver_config"
            "layout_config"
            "intro_config"
            "menu_config"
          ]) (lib.attrNames cfg.settings);
        message = ''
          programs.attract-mode.settings: unknown section name. attract-mode
          accepts only display, sound, input_map, general, plugin, saver_config,
          layout_config, intro_config and menu_config. Anything else is not
          treated as a section header and will corrupt the section before it.
        '';
      }
    ];

    home = {
      packages = [cfg.package buildRomlists];

      file =
        lib.optionalAttrs (cfg.manageConfig == true) {
          ".attract/attract.cfg".text = attractCfgText;
        }
        // lib.mapAttrs' (name: def:
          lib.nameValuePair ".attract/emulators/${name}.cfg" {
            text = mkEmulatorCfg def;
          })
        cfg.emulators;

      # Seed mode: write attract.cfg once and leave it writable, so attract-mode's
      # own configuration UI can persist changes to it.
      activation = lib.mkIf (cfg.manageConfig == "seed") {
        seedAttractCfg = lib.hm.dag.entryAfter ["writeBoundary"] ''
          attractCfg="${config.home.homeDirectory}/.attract/attract.cfg"
          if [ ! -e "$attractCfg" ]; then
            run mkdir -p "${config.home.homeDirectory}/.attract"
            run cp ${pkgs.writeText "attract.cfg.seed" attractCfgText} "$attractCfg"
            run chmod u+rw "$attractCfg"
          fi
        '';
      };
    };
  };
}
