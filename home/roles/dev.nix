# home/roles/dev.nix
{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../modules/delta
    ../modules/go
  ];

  home.packages = with pkgs; [
    git-absorb
    ijq
    jq
    presenterm
    taplo
    tig
    gum
    uv
  ];
}
