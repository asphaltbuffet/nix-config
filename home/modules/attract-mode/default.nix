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
        type = lib.types.attrsOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
        default = {};
        description = ''
          Additional key/value lines emitted in this display's section. A value
          may be a list, in which case the key is repeated once per element —
          needed for keys attract-mode allows more than once, such as `param`,
          which carries one layout option per line.
        '';
        example = lib.literalExpression ''
          {
            param = [ "system Arcade" "gameListElements 26" ];
          }
        '';
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
    ++ lib.flatten (lib.mapAttrsToList (
        k: v:
          map (one: {
            name = k;
            value = one;
          }) (lib.toList v)
      )
      d.extraSettings);

  # `menu_layout` and `startup_mode` are settings inside `general`, not sections
  # of their own — attract-mode's only top-level sections are display, sound,
  # input_map, general, plugin, saver_config, layout_config, intro_config and
  # menu_config (FeSettings::otherSettingStrings). Emitting an unknown header
  # does not start a section; the parser stays in whatever section preceded it
  # and misreads the keys that follow.
  # The key itself must never be interpolated here: this text becomes a Nix
  # store file, which is world-readable. A placeholder is rendered instead and
  # replaced at activation from a file only readable on the target machine.
  keyPlaceholder = "@THEGAMESDB_KEY@";

  # attractCfgText split on the placeholder, so activation can assemble the
  # real file by concatenating head + key + tail. Splitting here rather than
  # substituting there keeps the key out of any command line and away from
  # sed's replacement syntax. Guaranteed to yield exactly two parts: the
  # placeholder is emitted once, only when thegamesdbKeyFile is set.
  keyTemplateParts = lib.splitString keyPlaceholder attractCfgText;
  keyTemplateHead = lib.head keyTemplateParts;
  keyTemplateTail = lib.concatStringsSep keyPlaceholder (lib.tail keyTemplateParts);

  generalExtra =
    lib.optionalAttrs (cfg.menuLayout != null) {menu_layout = cfg.menuLayout;}
    // lib.optionalAttrs (cfg.startupMode != null) {startup_mode = cfg.startupMode;}
    // lib.optionalAttrs (cfg.thegamesdbKeyFile != null) {thegamesdb_key = keyPlaceholder;};

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

  # Rebuild every configured romlist.
  #
  # Two attract-mode behaviours shape this script. First, --build-romlist takes
  # several emulator names but merges them into ONE romlist, so it must be
  # called once per emulator rather than with the whole list. Second, it never
  # overwrites: given an existing nes.txt it writes nes1.txt, then nes2.txt, and
  # so on. Since a display references its romlist by bare name, re-running
  # without deleting first accumulates junk and refreshes nothing — hence the rm.
  #
  # writeShellApplication (see ADR-0008) shellchecks at build time and seals
  # PATH to runtimeInputs, so `attract` resolves without interpolating a store
  # path into the script body.
  buildRomlists = pkgs.writeShellApplication {
    name = "attract-build-romlists";
    runtimeInputs = [cfg.package];
    text = ''
      romlists="''${HOME}/.attract/romlists"
      mkdir -p "$romlists"

      for emu in ${lib.escapeShellArgs (lib.attrNames cfg.emulators)}; do
        echo "==> $emu"

        # Drop the current list and any numbered leftovers from earlier runs.
        rm -f "$romlists/$emu.txt"
        rm -f "$romlists/$emu"[0-9]*.txt

        attract --build-romlist "$emu"
      done

      echo
      echo "Romlists in $romlists:"
      ls -1 "$romlists"
    '';
  };
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

    thegamesdbKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression ''config.age.secrets."arcade/thegamesdbKey".path'';
      description = ''
        Path to a file containing the thegamesdb.net API key, read at
        activation time and substituted into `attract.cfg` as
        `thegamesdb_key`. Intended for an agenix secret path under
        `/run/agenix`, so the key stays encrypted in the repository.

        Required for any emulator using `infoSource = "thegamesdb.net"`: the
        key attract-mode ships with is a shared project key that upstream has
        revoked, so scraping without your own fails with `403 Invalid API key
        was provided`, which surfaces as `Error parsing json, text:` with an
        empty body during `--build-romlist`. Register at
        <https://thegamesdb.net/>.

        Setting this forces `attract.cfg` to be written at activation rather
        than symlinked from the Nix store: the secret is only readable on the
        target machine, and interpolating it at evaluation time would publish
        it to the world-readable store. The rendered template still comes from
        this module, so the file remains fully declarative — see ADR-0013.

        attract-mode offers no other injection point: it reads no relevant
        environment variables (`getenv` is used only for `HOME`), performs no
        variable expansion in config values, and its config parser is a flat
        line reader with no `include` directive.

        Emulators using `infoSource = "listxml"` (MAME) are unaffected; that
        scraper shells out to the local emulator rather than the network.
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
        # The placeholder is substituted only by the renderAttractCfg
        # activation script, which runs solely under manageConfig = true. In
        # seed mode the template is copied verbatim, so the literal
        # placeholder would land in attract.cfg and every scrape would fail
        # with a 403 — and seed mode never rewrites the file, so it would stay
        # broken.
        assertion = !(cfg.manageConfig == "seed" && cfg.thegamesdbKeyFile != null);
        message = ''
          programs.attract-mode: thegamesdbKeyFile requires manageConfig = true.
          Under manageConfig = "seed" the config is written once and never
          rewritten, so the key placeholder would never be substituted.
        '';
      }
      {
        # keyTemplateParts assumes the placeholder occurs exactly once, emitted
        # by generalExtra. A hand-written occurrence in `settings` would split
        # the template into three parts and leave a literal placeholder in the
        # rendered file.
        assertion = !(lib.any (kv: lib.any (v: lib.hasInfix keyPlaceholder v) (lib.attrValues kv)) (lib.attrValues cfg.settings));
        message = ''
          programs.attract-mode.settings: the string ${keyPlaceholder} is
          reserved for the thegamesdbKeyFile substitution and must not appear
          in a setting value.
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
        # A secret in the config forces activation-time writing: home.file
        # content becomes a world-readable store path, so the key would be
        # published. renderAttractCfg below writes the same rendered template
        # with the placeholder substituted.
        lib.optionalAttrs (cfg.manageConfig == true && cfg.thegamesdbKeyFile == null) {
          ".attract/attract.cfg".text = attractCfgText;
        }
        // lib.mapAttrs' (name: def:
          lib.nameValuePair ".attract/emulators/${name}.cfg" {
            text = mkEmulatorCfg def;
          })
        cfg.emulators;

      activation =
        # Seed mode: write attract.cfg once and leave it writable, so
        # attract-mode's own configuration UI can persist changes to it.
        lib.optionalAttrs (cfg.manageConfig == "seed") {
          seedAttractCfg = lib.hm.dag.entryAfter ["writeBoundary"] ''
            attractCfg="${config.home.homeDirectory}/.attract/attract.cfg"
            if [ ! -e "$attractCfg" ]; then
              run mkdir -p "${config.home.homeDirectory}/.attract"
              run cp ${pkgs.writeText "attract.cfg.seed" attractCfgText} "$attractCfg"
              run chmod u+rw "$attractCfg"
            fi
          '';
        }
        # Managed mode with a secret: rewrite attract.cfg on every activation,
        # substituting the key from a file readable only on this machine. The
        # file is still fully declarative — the template comes from this
        # module and any manual edit is overwritten on the next activation,
        # matching manageConfig = true semantics (ADR-0013).
        #
        # Anchored after checkLinkTargets rather than writeBoundary: sibling
        # scripts sharing an anchor have unspecified relative order, and this
        # must run after home.file links are in place.
        // lib.optionalAttrs (cfg.manageConfig == true && cfg.thegamesdbKeyFile != null) {
          renderAttractCfg = lib.hm.dag.entryAfter ["checkLinkTargets" "writeBoundary"] ''
            attractCfg="${config.home.homeDirectory}/.attract/attract.cfg"
            keyFile="${toString cfg.thegamesdbKeyFile}"
            if [ -r "$keyFile" ]; then
              run mkdir -p "${config.home.homeDirectory}/.attract"

              # Assemble by concatenation rather than substitution. The two
              # halves are split on the placeholder at eval time, so the key
              # is never a command argument (it would otherwise be visible in
              # /proc/*/cmdline) and never passed through sed, whose
              # replacement text would mangle a key containing & | or \.
              #
              # Written to a temp file then moved: `run` skips execution under
              # --dry-run but a `>` redirection is applied by the shell
              # regardless, which would truncate the live config.
              #
              # The whole block is therefore skipped under --dry-run rather
              # than relying on `run`: mktemp and the redirection are not
              # commands `run` can wrap, so a dry run would otherwise create a
              # temp file holding the real key and never move or remove it.
              if [ -n "$DRY_RUN_CMD" ]; then
                echo "would write $attractCfg with the thegamesdb key substituted"
              else
                # 0600 deliberately, unlike the 0444 a store symlink would give
                # or the u+rw of seed mode: this copy carries the API key.
                # mktemp already creates 0600; set it explicitly so the
                # guarantee does not rest on the ambient umask.
                tmp=$(mktemp "${config.home.homeDirectory}/.attract/.attract.cfg.XXXXXX")
                # Activation runs under `set -eu`, so a failure mid-write would
                # otherwise abort with the key left behind in $tmp.
                trap 'rm -f "$tmp"' EXIT
                ${pkgs.coreutils}/bin/chmod 0600 "$tmp"
                {
                  cat ${pkgs.writeText "attract.cfg.head" keyTemplateHead}
                  tr -d '\n' < "$keyFile"
                  cat ${pkgs.writeText "attract.cfg.tail" keyTemplateTail}
                } > "$tmp"
                ${pkgs.coreutils}/bin/mv -f "$tmp" "$attractCfg"
                trap - EXIT
              fi
            else
              echo "attract-mode: key file $keyFile not readable; leaving attract.cfg untouched" >&2
            fi
          '';
        };
    };
  };
}
