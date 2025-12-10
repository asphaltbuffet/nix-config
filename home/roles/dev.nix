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
    gccgo15
    git-absorb
    ijq
    jj
    jq
    presenterm
    taplo
    go-task
    tig
    gum
    uv
  ];
}
