# home/modules/micasa/default.nix
#
# micasa TUI. Syncs through the relay on bunyip (ADR-0021); joining a machine
# to the household is a one-time interactive step (docs/references/micasa-sop.md),
# because the relay URL, device keys and token are runtime state, not config.
# config.toml is left unmanaged.
{
  inputs,
  pkgs,
  ...
}: {
  home.packages = [inputs.micasa.packages.${pkgs.stdenv.hostPlatform.system}.micasa];
}
