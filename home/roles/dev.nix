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
    # go
    gccgo15

    git-absorb
    ijq
    jq
    jujutsu
    presenterm
    taplo
    go-task
    tig
    gum
    uv
  ];
}
