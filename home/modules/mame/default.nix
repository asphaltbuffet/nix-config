# home/modules/mame/default.nix
#
# Interface module for MAME (ADR-0014): declares programs.mame rather than
# setting someone else's options, because home-manager has no upstream module
# for it. Written to upstream conventions so it can be contributed; keep it free
# of any assumption about a particular machine — no /mnt/roms, no cabinet
# layouts, no attract-mode awareness.
#
# Scope is deliberately partial: the package, a wrapper, and declarative
# control configuration rendered to MAME's -ctrlr file (ADR-0017). MAME's
# cfg/<set>.cfg is deliberately NOT managed — MAME rewrites it on exit and it
# carries DIP switch and video state, so owning it would lose those.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.mame;

  # One <system> block. `ports` renders to the <port>/<newseq> form; the
  # <remap origcode= newcode=> form is deliberately unimplemented (see the
  # option description).
  scopeType = lib.types.submodule {
    options.ports = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = ''
        MAME port type to input sequence, e.g. `P1_BUTTON1 = "JOYCODE_1_BUTTON1"`.

        The value is written verbatim as a `standard` sequence, so MAME's own
        syntax applies — `OR` joins alternatives and a space joins a chord.
      '';
      example = {
        P1_BUTTON1 = "JOYCODE_1_BUTTON1 OR KEYCODE_LCONTROL";
        UI_MENU = "JOYCODE_1_BUTTON4";
      };
    };
  };

  # MAME resolves precedence itself across five match levels; these sections
  # only make the intent legible. Order matters only in that the rendered file
  # must list them the way MAME expects to find them — matching is by the
  # `name` attribute, not by position, but keeping the file in broad-to-narrow
  # order makes it readable.
  renderPort = port: seq:
    "\t\t\t<port type=\"${port}\">\n"
    + "\t\t\t\t<newseq type=\"standard\">${seq}</newseq>\n"
    + "\t\t\t</port>";

  renderScope = name: scope:
    "\t<system name=\"${name}\">\n"
    + "\t\t<input>\n"
    + lib.concatStringsSep "\n" (lib.mapAttrsToList renderPort scope.ports)
    + "\n\t\t</input>\n"
    + "\t</system>";

  allScopes =
    lib.optional (cfg.controls.default.ports != {})
    (renderScope "default" cfg.controls.default)
    ++ lib.mapAttrsToList renderScope cfg.controls.bySourceFile
    ++ lib.mapAttrsToList renderScope cfg.controls.byParent
    ++ lib.mapAttrsToList renderScope cfg.controls.bySet;

  ctrlrFile = pkgs.writeText "${cfg.ctrlrName}.cfg" ''
    <?xml version="1.0"?>
    <mameconfig version="10">
    ${lib.concatStringsSep "\n" allScopes}
    </mameconfig>
  '';

  # MAME finds the file by searching ctrlrpath for `<ctrlr>.cfg`, so the file
  # must sit in a directory under its configured name.
  ctrlrDir = pkgs.runCommand "mame-ctrlr" {} ''
    mkdir -p $out
    cp ${ctrlrFile} $out/${cfg.ctrlrName}.cfg
  '';

  hasControls = allScopes != [];
in {
  options.programs.mame = {
    enable = lib.mkEnableOption "MAME";

    package = lib.mkPackageOption pkgs "mame" {};

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Extra arguments baked into {option}`finalPackage`'s `mame` executable.

        These are prepended, so a caller passing the same option on the command
        line still wins — MAME's option parser takes the last occurrence.
      '';
      example = ["-skip_gameinfo"];
    };

    ignoreDevices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        USB `VID/PID` pairs SDL should skip when scanning for controllers, in
        hexadecimal (`"0x0079/0x0011"`). Set as
        `SDL_GAMECONTROLLER_IGNORE_DEVICES` on {option}`finalPackage`.

        Worth setting when some devices must not reach MAME at all, because
        MAME addresses controllers by *enumeration index* — `JOYCODE_1_*` and
        so on — with no way to bind a device by identity. SDL enumerates
        recognised game controllers before plain joysticks, so attaching a
        controller SDL has a mapping for renumbers every device behind it and
        silently retargets an entire controller configuration.
      '';
      example = ["0x0079/0x0011"];
    };

    ctrlrName = lib.mkOption {
      type = lib.types.str;
      default = "nix";
      description = ''
        Basename of the generated controller configuration file, passed to MAME
        as `-ctrlr`. Rarely worth changing; it only has to not collide with a
        file already on {option}`package`'s built-in `ctrlrpath`.
      '';
    };

    controls = {
      default = lib.mkOption {
        type = scopeType;
        default = {};
        description = ''
          Control mapping applied to every machine, unless a narrower scope
          overrides the same port.
        '';
      };

      bySourceFile = lib.mkOption {
        type = lib.types.attrsOf scopeType;
        default = {};
        description = ''
          Control mappings keyed by MAME driver source file, applying to every
          machine defined in it — `"cps2.cpp"` covers the whole CPS2 library.

          Usually the right place for cabinet control config: one entry per
          driver family, with {option}`bySet` reserved for exceptions.
        '';
        example = lib.literalExpression ''
          { "cps2.cpp".ports.P1_BUTTON1 = "JOYCODE_1_BUTTON1"; }
        '';
      };

      byParent = lib.mkOption {
        type = lib.types.attrsOf scopeType;
        default = {};
        description = ''
          Control mappings keyed by a parent machine's short name, applying to
          it and to every clone of it.
        '';
        example = lib.literalExpression ''
          { sf2.ports.P1_BUTTON6 = "JOYCODE_1_BUTTON6"; }
        '';
      };

      bySet = lib.mkOption {
        type = lib.types.attrsOf scopeType;
        default = {};
        description = ''
          Control mappings keyed by an individual machine's short name.

          Scopes accumulate rather than replace, so an entry here need only
          state what differs from the broader scopes that also match.
        '';
        example = lib.literalExpression ''
          { centiped.ports.P1_BUTTON1 = "JOYCODE_1_BUTTON3"; }
        '';
      };
    };

    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = ''
        Resulting MAME package, wrapped with any arguments this module manages.

        Use this rather than {option}`package` wherever MAME is launched — a
        front-end's emulator definition, for instance — so that options this
        module owns cannot drift from the executable that receives them.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # A bySourceFile key that is not a source filename matches nothing, and
    # MAME reports that silently — not even at -v. Nix is the only place the
    # mistake is catchable.
    assertions = [
      {
        assertion = lib.all (lib.hasSuffix ".cpp") (lib.attrNames cfg.controls.bySourceFile);
        message = let
          bad = lib.filter (n: !(lib.hasSuffix ".cpp" n)) (lib.attrNames cfg.controls.bySourceFile);
        in ''
          programs.mame.controls.bySourceFile keys must be MAME driver source
          filenames ending in `.cpp`. Offending: ${lib.concatStringsSep ", " bad}.

          A machine short name belongs in `byParent` or `bySet` instead.
        '';
      }
    ];

    # -ctrlrpath and -ctrlr are baked in together from the same value: MAME
    # treats an unopenable controller file as a fatal error, so every game
    # would fail to launch if the two ever disagreed.
    programs.mame.extraArgs = lib.mkIf hasControls (lib.mkBefore [
      "-ctrlrpath"
      "${ctrlrDir}"
      "-ctrlr"
      cfg.ctrlrName
    ]);

    programs.mame.finalPackage =
      if cfg.extraArgs == [] && cfg.ignoreDevices == []
      then cfg.package
      else
        pkgs.symlinkJoin {
          name = "mame-wrapped-${cfg.package.version}";
          paths = [cfg.package];
          nativeBuildInputs = [pkgs.makeWrapper];
          # `--add-flags` prepends, leaving a caller's own arguments later on the
          # command line and therefore authoritative. The SDL variable is read
          # by SDL itself, not by MAME — MAME never sees it.
          postBuild = ''
            wrapProgram $out/bin/mame \
              ${lib.optionalString (cfg.extraArgs != [])
              "--add-flags ${lib.escapeShellArg (lib.concatStringsSep " " cfg.extraArgs)}"} \
              ${lib.optionalString (cfg.ignoreDevices != [])
              "--set-default SDL_GAMECONTROLLER_IGNORE_DEVICES ${lib.escapeShellArg (lib.concatStringsSep "," cfg.ignoreDevices)}"}
          '';
          inherit (cfg.package) meta;
        };

    home.packages = [cfg.finalPackage];
  };
}
