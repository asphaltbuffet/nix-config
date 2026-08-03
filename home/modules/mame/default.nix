# home/modules/mame/default.nix
#
# Interface module for MAME (ADR-0014): declares programs.mame rather than
# setting someone else's options, because home-manager has no upstream module
# for it. Written to upstream conventions so it can be contributed; keep it free
# of any assumption about a particular machine — no /mnt/roms, no cabinet
# layouts, no attract-mode awareness.
#
# Scope is deliberately partial. This step establishes the package and the
# wrapper only; declarative control configuration (`controls`, rendering the
# -ctrlr file per ADR-0017) lands next and slots in without changing what is
# here.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.mame;
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
    programs.mame.finalPackage =
      if cfg.extraArgs == []
      then cfg.package
      else
        pkgs.symlinkJoin {
          name = "mame-wrapped-${cfg.package.version}";
          paths = [cfg.package];
          nativeBuildInputs = [pkgs.makeWrapper];
          # `--add-flags` prepends, leaving a caller's own arguments later on the
          # command line and therefore authoritative.
          postBuild = ''
            wrapProgram $out/bin/mame \
              --add-flags ${lib.escapeShellArg (lib.concatStringsSep " " cfg.extraArgs)}
          '';
          inherit (cfg.package) meta;
        };

    home.packages = [cfg.finalPackage];
  };
}
