# home/roles/dev.nix
{ pkgs, lib, ... }:
{
  imports = [
    ../modules/delta.nix
    ../modules/go.nix
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
